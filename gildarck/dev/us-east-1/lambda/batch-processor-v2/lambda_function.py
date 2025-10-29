"""
Batch Processor v2.0 - Google Photos Style
Processes SQS messages for batch upload URL generation
"""

import json
import boto3
import os
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import logging
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Environment variables
BUCKET_NAME = os.environ['BUCKET_NAME']
BATCH_TABLE_NAME = os.environ['BATCH_TABLE_NAME']
MAX_RETRY_ATTEMPTS = int(os.environ.get('MAX_RETRY_ATTEMPTS', '3'))
ENABLE_THROTTLING = os.environ.get('ENABLE_THROTTLING', 'true').lower() == 'true'

# DynamoDB table
batch_table = dynamodb.Table(BATCH_TABLE_NAME)

def lambda_handler(event, context):
    """Main Lambda handler for SQS events"""
    try:
        logger.info(f"Processing {len(event.get('Records', []))} SQS messages")
        
        results = []
        for record in event.get('Records', []):
            try:
                result = process_sqs_message(record)
                results.append(result)
            except Exception as e:
                logger.error(f"Error processing SQS record: {str(e)}")
                results.append({'success': False, 'error': str(e)})
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': len(results),
                'successful': sum(1 for r in results if r.get('success')),
                'failed': sum(1 for r in results if not r.get('success'))
            })
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def process_sqs_message(record: Dict) -> Dict[str, Any]:
    """Process individual SQS message"""
    try:
        # Parse message body
        message_body = json.loads(record['body'])
        
        # Extract batch information
        batch_id = message_body.get('batch_id')
        master_batch_id = message_body.get('master_batch_id')
        user_id = message_body.get('user_id')
        files = message_body.get('files', [])
        strategy = message_body.get('strategy', {})
        
        logger.info(f"Processing batch {batch_id} with {len(files)} files")
        
        # Update batch status to processing
        update_batch_status(batch_id, 'processing', 0)
        
        # Process files and generate presigned URLs
        upload_urls = generate_batch_upload_urls(files, user_id, strategy)
        
        # Update batch with results (without storing URLs to avoid size limit)
        update_batch_completion(batch_id, len(upload_urls), len(files))
        
        # Update master batch if applicable
        if master_batch_id:
            update_master_batch_progress(master_batch_id)
        
        logger.info(f"Batch {batch_id} completed successfully with {len(upload_urls)} URLs")
        
        return {
            'success': True,
            'batch_id': batch_id,
            'processed_files': len(upload_urls)
        }
        
    except Exception as e:
        logger.error(f"Error processing batch: {str(e)}")
        
        # Update batch status to failed
        batch_id = message_body.get('batch_id') if 'message_body' in locals() else 'unknown'
        try:
            update_batch_status(batch_id, 'failed', 0, str(e))
        except:
            pass
        
        return {
            'success': False,
            'batch_id': batch_id,
            'error': str(e)
        }

def generate_batch_upload_urls(files: List[Dict], user_id: str, strategy: Dict) -> List[Dict]:
    """Generate presigned URLs for batch of files"""
    upload_urls = []
    
    try:
        logger.info(f"Files type: {type(files)}, Files content: {files[:2] if files else 'empty'}")
        
        for i, file_info in enumerate(files):
            try:
                logger.info(f"File {i} type: {type(file_info)}, content: {file_info}")
                
                # 🔧 FIX: Handle both string and object formats
                if isinstance(file_info, str):
                    # If it's a string, treat it as filename
                    filename = file_info
                    content_type = 'application/octet-stream'
                elif isinstance(file_info, dict):
                    # If it's a dict, extract filename and contentType
                    filename = file_info.get('filename', f'file_{i}')
                    content_type = file_info.get('contentType', 'application/octet-stream')
                else:
                    # Skip invalid entries
                    logger.warning(f"Skipping invalid file_info at index {i}: {type(file_info)}")
                    continue
                
                logger.info(f"Processing file {i}: {filename} ({content_type})")
                
                # Generate S3 key with date organization
                s3_key = generate_s3_key(user_id, filename)
                
                logger.info(f"Generated S3 key for {filename}: {s3_key}")
                
                # Generate presigned URL
                presigned_url = s3_client.generate_presigned_url(
                    'put_object',
                    Params={
                        'Bucket': BUCKET_NAME,
                        'Key': s3_key,
                        'ContentType': content_type
                    },
                    ExpiresIn=3600  # 1 hour
                )
                
                upload_urls.append({
                    'filename': filename,
                    'upload_url': presigned_url,
                    'upload_type': 'simple',
                    's3_key': s3_key,
                    'content_type': content_type
                })
                
                logger.info(f"Generated upload URL for {filename}")
                
            except Exception as e:
                logger.error(f"Error processing file {i} ({file_info}): {str(e)}")
                # Continue with next file instead of failing entire batch
                continue
            
            # Apply throttling if enabled
            if ENABLE_THROTTLING and isinstance(strategy, dict) and strategy.get('throttling'):
                time.sleep(0.01)  # 10ms delay between URL generations
        
        return upload_urls
        
    except Exception as e:
        logger.error(f"Error generating upload URLs: {str(e)}")
        raise

def update_batch_status(batch_id: str, status: str, processed_files: int, error: str = None):
    """Update batch status in DynamoDB"""
    try:
        update_expression = "SET #status = :status, processed_files = :processed, updated_at = :updated"
        expression_values = {
            ':status': status,
            ':processed': processed_files,
            ':updated': datetime.utcnow().isoformat()
        }
        expression_names = {'#status': 'status'}
        
        if error:
            update_expression += ", error_message = :error"
            expression_values[':error'] = error
        
        batch_table.update_item(
            Key={'batch_id': batch_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ExpressionAttributeNames=expression_names
        )
        
        logger.info(f"Updated batch {batch_id} status to {status}")
        
    except Exception as e:
        logger.error(f"Error updating batch status: {str(e)}")

def update_batch_completion(batch_id: str, successful_urls: int, total_files: int):
    """Update batch with completion data (without storing URLs to avoid size limit)"""
    try:
        batch_table.update_item(
            Key={'batch_id': batch_id},
            UpdateExpression="SET #status = :status, processed_files = :processed, successful_urls = :count, updated_at = :updated",
            ExpressionAttributeValues={
                ':status': 'completed',
                ':processed': total_files,
                ':count': successful_urls,
                ':updated': datetime.utcnow().isoformat()
            },
            ExpressionAttributeNames={'#status': 'status'}
        )
        
        logger.info(f"Batch {batch_id} completed with {successful_urls} URLs generated")
        
    except Exception as e:
        logger.error(f"Error updating batch completion: {str(e)}")
        raise

def update_master_batch_progress(master_batch_id: str):
    """Update master batch progress"""
    try:
        # Get master batch info
        response = batch_table.get_item(Key={'batch_id': master_batch_id})
        if 'Item' not in response:
            logger.warning(f"Master batch {master_batch_id} not found")
            return
        
        master_batch = response['Item']
        
        # Query all chunks for this master batch
        chunks_response = batch_table.scan(
            FilterExpression='master_batch_id = :master_id',
            ExpressionAttributeValues={':master_id': master_batch_id}
        )
        
        chunks = chunks_response.get('Items', [])
        completed_chunks = sum(1 for chunk in chunks if chunk.get('status') == 'completed')
        failed_chunks = sum(1 for chunk in chunks if chunk.get('status') == 'failed')
        total_chunks = master_batch.get('total_chunks', 0)
        
        # Calculate total progress
        total_files = sum(chunk.get('total_files', 0) for chunk in chunks)
        processed_files = sum(chunk.get('processed_files', 0) for chunk in chunks)
        
        # Determine master status
        if completed_chunks == total_chunks:
            master_status = 'completed'
        elif failed_chunks > 0:
            master_status = 'partial_failure'
        else:
            master_status = 'processing'
        
        # Update master batch
        batch_table.update_item(
            Key={'batch_id': master_batch_id},
            UpdateExpression="SET #status = :status, processed_files = :processed, completed_chunks = :completed, updated_at = :updated",
            ExpressionAttributeValues={
                ':status': master_status,
                ':processed': processed_files,
                ':completed': completed_chunks,
                ':updated': datetime.utcnow().isoformat()
            },
            ExpressionAttributeNames={'#status': 'status'}
        )
        
        logger.info(f"Master batch {master_batch_id}: {completed_chunks}/{total_chunks} chunks completed, status: {master_status}")
        
    except Exception as e:
        logger.error(f"Error updating master batch progress: {str(e)}")

def generate_s3_key(user_id: str, filename: str) -> str:
    """Generate S3 key with date-based organization"""
    now = datetime.utcnow()
    year = now.strftime('%Y')
    month = now.strftime('%m')
    
    # Clean filename
    clean_filename = filename.replace(' ', '_').replace('(', '').replace(')', '')
    
    return f"{user_id}/originals/{year}/{month}/{clean_filename}"
