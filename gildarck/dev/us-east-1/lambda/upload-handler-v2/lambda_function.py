"""
Upload Handler v2.0 - Google Photos Style Batch Upload System
Handles individual and batch uploads with intelligent routing
"""

import json
import boto3
import os
import uuid
import hashlib
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import logging
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients - Create fresh clients on each request
def get_s3_client():
    return boto3.client('s3')

def get_dynamodb():
    return boto3.resource('dynamodb')

def get_sqs_client():
    return boto3.client('sqs')

# Environment variables
BUCKET_NAME = os.environ['BUCKET_NAME']
BATCH_TABLE_NAME = os.environ['BATCH_TABLE_NAME']
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']
DEDUPLICATION_TABLE = os.environ.get('DEDUPLICATION_TABLE', 'gildarck-media-metadata-dev')
MAX_PARALLEL_STREAMS = int(os.environ.get('MAX_PARALLEL_STREAMS', '10'))
BATCH_THRESHOLD = int(os.environ.get('BATCH_THRESHOLD', '10'))
CHUNK_SIZE = int(os.environ.get('CHUNK_SIZE', '50'))

# DynamoDB tables - Get fresh connections
def get_batch_table():
    return get_dynamodb().Table(BATCH_TABLE_NAME)

def get_dedup_table():
    return get_dynamodb().Table(DEDUPLICATION_TABLE)

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Extract HTTP method and path
        http_method = event.get('httpMethod', 'POST')
        path = event.get('path', '')
        
        # CORS headers
        cors_headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
            'Access-Control-Allow-Credentials': 'false'
        }
        
        # Handle OPTIONS request
        if http_method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({'message': 'CORS preflight'})
            }
        
        # Route requests (handle both with and without trailing slash)
        if path.endswith('/batch-initiate') or path.endswith('/batch-initiate/'):
            return handle_batch_initiate(event, cors_headers)
        elif path.endswith('/batch-status') or path.endswith('/batch-status/'):
            return handle_batch_status(event, cors_headers)
        elif path.endswith('/batch-chunk-urls') or path.endswith('/batch-chunk-urls/'):
            return handle_batch_chunk_urls(event, cors_headers)
        elif path.endswith('/upload-simple') or path.endswith('/upload-simple/'):
            return handle_simple_upload(event, cors_headers)
        else:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }

def handle_batch_initiate(event, cors_headers):
    """Handle batch upload initiation"""
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        files = body.get('files', [])
        user_id = extract_user_id(event)
        
        if not files:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'No files provided'})
            }
        
        logger.info(f"Initiating batch upload for {len(files)} files, user: {user_id}")
        
        # Determine strategy based on file count
        if len(files) < BATCH_THRESHOLD:
            # Simple batch - process immediately
            return process_simple_batch(files, user_id, cors_headers)
        else:
            # Large batch - use SQS chunking
            return process_chunked_batch(files, user_id, cors_headers)
            
    except Exception as e:
        logger.error(f"Error in batch initiate: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }

def handle_batch_status(event, cors_headers):
    """Handle batch status check"""
    try:
        # Get batch_id from query parameters
        query_params = event.get('queryStringParameters') or {}
        batch_id = query_params.get('batch_id')
        
        if not batch_id:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'batch_id required'})
            }
        
        # Get batch status from DynamoDB
        response = get_batch_table().get_item(Key={'batch_id': batch_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({'error': 'Batch not found'})
            }
        
        batch_item = response['Item']
        
        # Calculate progress
        total_files = int(batch_item.get('total_files', 0))
        processed_files = int(batch_item.get('processed_files', 0))
        progress = (processed_files / total_files * 100) if total_files > 0 else 0
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'batch_id': batch_id,
                'status': batch_item.get('status', 'unknown'),
                'progress': round(progress, 2),
                'total_files': total_files,
                'processed_files': processed_files,
                'created_at': batch_item.get('created_at'),
                'updated_at': batch_item.get('updated_at')
            })
        }
        
    except Exception as e:
        logger.error(f"Error checking batch status: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }

def handle_batch_chunk_urls(event, cors_headers):
    """Generate presigned URLs for specific chunk - Google Photos style"""
    try:
        body = json.loads(event.get('body', '{}'))
        batch_id = body.get('batch_id')
        chunk_index = body.get('chunk_index', 0)
        
        if not batch_id:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'batch_id required'})
            }
        
        user_id = extract_user_id(event)
        
        # Get master batch
        response = get_batch_table().get_item(Key={'batch_id': batch_id})
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({'error': 'Batch not found'})
            }
        
        master_batch = response['Item']
        
        # Verify ownership
        if master_batch.get('user_id') != user_id:
            return {
                'statusCode': 403,
                'headers': cors_headers,
                'body': json.dumps({'error': 'Access denied'})
            }
        
        # Get chunk batch ID
        queued_batches = master_batch.get('queued_batches', [])
        if chunk_index >= len(queued_batches):
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'Invalid chunk_index'})
            }
        
        chunk_batch_id = queued_batches[chunk_index]
        
        # Get chunk details
        chunk_response = get_batch_table().get_item(Key={'batch_id': chunk_batch_id})
        if 'Item' not in chunk_response:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({'error': 'Chunk not found'})
            }
        
        chunk = chunk_response['Item']
        file_names = chunk.get('file_names', [])
        
        # Generate fresh URLs
        upload_urls = []
        for filename in file_names:
            s3_key = generate_s3_key(user_id, filename)
            
            presigned_url = get_s3_client().generate_presigned_url(
                'put_object',
                Params={
                    'Bucket': BUCKET_NAME,
                    'Key': s3_key,
                    'ContentType': 'application/octet-stream'
                },
                ExpiresIn=900  # 15 minutes - Google Photos style
            )
            
            upload_urls.append({
                'filename': filename,
                'upload_url': presigned_url,
                's3_key': s3_key
            })
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'batch_id': batch_id,
                'chunk_index': chunk_index,
                'chunk_batch_id': chunk_batch_id,
                'upload_urls': upload_urls,
                'expires_in': 900,
                'total_files': len(upload_urls)
            })
        }
        
    except Exception as e:
        logger.error(f"Error in batch chunk URLs: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }

def handle_simple_upload(event, cors_headers):
    """Handle single file upload"""
    try:
        body = json.loads(event.get('body', '{}'))
        filename = body.get('filename')
        content_type = body.get('contentType', 'application/octet-stream')
        user_id = extract_user_id(event)
        
        if not filename:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'filename required'})
            }
        
        # Generate S3 key
        s3_key = generate_s3_key(user_id, filename)
        
        # Generate presigned URL
        presigned_url = get_s3_client().generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': s3_key,
                'ContentType': content_type
            },
            ExpiresIn=3600
        )
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'upload_url': presigned_url,
                's3_key': s3_key,
                'expires_in': 3600
            })
        }
        
    except Exception as e:
        logger.error(f"Error in simple upload: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }

def process_simple_batch(files: List[Dict], user_id: str, cors_headers: Dict) -> Dict:
    """Process small batch immediately"""
    try:
        batch_id = str(uuid.uuid4())
        
        # Generate upload URLs
        upload_urls = []
        for file_info in files:
            filename = file_info.get('filename', '')
            content_type = file_info.get('contentType', 'application/octet-stream')
            
            s3_key = generate_s3_key(user_id, filename)
            
            presigned_url = get_s3_client().generate_presigned_url(
                'put_object',
                Params={
                    'Bucket': BUCKET_NAME,
                    'Key': s3_key,
                    'ContentType': content_type
                },
                ExpiresIn=3600
            )
            
            upload_urls.append({
                'filename': filename,
                'upload_url': presigned_url,
                's3_key': s3_key,
                'content_type': content_type
            })
        
        # Store batch metadata (without URLs to avoid size limit)
        get_batch_table().put_item(
            Item={
                'batch_id': batch_id,
                'user_id': user_id,
                'status': 'completed',
                'total_files': len(files),
                'processed_files': len(files),
                'file_names': [f['filename'] for f in files],
                'strategy': {'type': 'simple'},
                'created_at': datetime.utcnow().isoformat(),
                'updated_at': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(hours=24)).timestamp())
            }
        )
        
        logger.info(f"Simple batch {batch_id} completed with {len(upload_urls)} URLs")
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'batch_id': batch_id,
                'status': 'completed',
                'upload_urls': upload_urls,
                'strategy': 'simple'
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing simple batch: {str(e)}")
        raise

def process_chunked_batch(files: List[Dict], user_id: str, cors_headers: Dict) -> Dict:
    """Process large batch using SQS chunks"""
    try:
        master_batch_id = str(uuid.uuid4())
        
        # Split files into chunks
        file_chunks = [files[i:i + CHUNK_SIZE] for i in range(0, len(files), CHUNK_SIZE)]
        
        queued_batches = []
        
        # Send each chunk to SQS
        for i, chunk in enumerate(file_chunks):
            chunk_batch_id = str(uuid.uuid4())
            
            # Send to SQS
            message = {
                'batch_id': chunk_batch_id,
                'master_batch_id': master_batch_id,
                'user_id': user_id,
                'files': chunk,
                'chunk_index': i,
                'total_chunks': len(file_chunks),
                'strategy': {'type': 'chunked'}
            }
            
            get_sqs_client().send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(message)
            )
            
            # Store chunk metadata
            get_batch_table().put_item(
                Item={
                    'batch_id': chunk_batch_id,
                    'master_batch_id': master_batch_id,
                    'user_id': user_id,
                    'status': 'queued',
                    'total_files': len(chunk),
                    'processed_files': 0,
                    'file_names': [f['filename'] for f in chunk],
                    'strategy': {'type': 'chunked'},
                    'chunk_index': i,
                    'total_chunks': len(file_chunks),
                    'created_at': datetime.utcnow().isoformat(),
                    'ttl': int((datetime.utcnow() + timedelta(hours=24)).timestamp())
                }
            )
            
            queued_batches.append(chunk_batch_id)
        
        # Store master batch metadata
        get_batch_table().put_item(
            Item={
                'batch_id': master_batch_id,
                'user_id': user_id,
                'status': 'processing',
                'total_files': len(files),
                'processed_files': 0,
                'total_chunks': len(file_chunks),
                'completed_chunks': 0,
                'queued_batches': queued_batches,
                'strategy': 'chunked',
                'created_at': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(hours=24)).timestamp())
            }
        )
        
        logger.info(f"Chunked batch {master_batch_id} queued with {len(file_chunks)} chunks")
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'batch_id': master_batch_id,
                'status': 'processing',
                'total_chunks': len(file_chunks),
                'queued_batches': queued_batches,
                'strategy': 'chunked'
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing chunked batch: {str(e)}")
        raise

def extract_user_id(event: Dict) -> str:
    """Extract user ID from JWT token"""
    try:
        # Try to get from authorizer context first (API Gateway JWT authorizer)
        authorizer = event.get('requestContext', {}).get('authorizer', {})
        if 'sub' in authorizer:
            return authorizer['sub']
        
        # Fallback: extract from Authorization header
        headers = event.get('headers', {})
        auth_header = headers.get('Authorization') or headers.get('authorization')
        
        if auth_header and auth_header.startswith('Bearer '):
            import base64
            token = auth_header.split(' ')[1]
            
            # Decode JWT payload (without verification for now)
            payload_b64 = token.split('.')[1]
            # Add padding if needed
            payload_b64 += '=' * (4 - len(payload_b64) % 4)
            payload = json.loads(base64.b64decode(payload_b64))
            
            # Extract Cognito sub
            return payload.get('sub', 'anonymous-user')
        
        logger.warning("No valid user ID found in request")
        return 'anonymous-user'
        
    except Exception as e:
        logger.error(f"Error extracting user ID: {str(e)}")
        return 'anonymous-user'

def generate_s3_key(user_id: str, filename: str) -> str:
    """Generate S3 key with date-based organization"""
    now = datetime.utcnow()
    year = now.strftime('%Y')
    month = now.strftime('%m')
    
    # Clean filename
    clean_filename = filename.replace(' ', '_').replace('(', '').replace(')', '')
    
    return f"{user_id}/originals/{year}/{month}/{clean_filename}"
