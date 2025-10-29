"""
Enhanced Upload Handler v2.0 - Google Photos Style
Handles 1-10,000 files with intelligent batching, deduplication, and parallel streams
"""

import json
import boto3
import hashlib
import uuid
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
from botocore.exceptions import ClientError
import base64
from urllib.parse import unquote

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sqs_client = boto3.client('sqs')

# Environment variables
BUCKET_NAME = os.environ['BUCKET_NAME']
BATCH_TABLE_NAME = os.environ['BATCH_TABLE_NAME']
DEDUPLICATION_TABLE = os.environ['DEDUPLICATION_TABLE']
MAX_PARALLEL_STREAMS = int(os.environ.get('MAX_PARALLEL_STREAMS', '10'))
COMPRESSION_THRESHOLD = int(os.environ.get('COMPRESSION_THRESHOLD', '26214400'))  # 25MB
CHUNK_SIZE = int(os.environ.get('CHUNK_SIZE', '8388608'))  # 8MB
ENABLE_DEDUPLICATION = os.environ.get('ENABLE_DEDUPLICATION', 'true').lower() == 'true'
ENABLE_COMPRESSION = os.environ.get('ENABLE_COMPRESSION', 'true').lower() == 'true'

# DynamoDB tables
batch_table = dynamodb.Table(BATCH_TABLE_NAME)
dedup_table = dynamodb.Table(DEDUPLICATION_TABLE)

def lambda_handler(event, context):
    """Main Lambda handler with CORS support"""
    try:
        # Handle CORS preflight
        if event.get('httpMethod') == 'OPTIONS':
            return cors_response({}, 200)
        
        # Extract path and method
        path = event.get('path', '')
        method = event.get('httpMethod', 'GET')
        
        logger.info(f"Processing {method} {path}")
        
        # Route requests
        if path == '/upload/analyze' and method == 'POST':
            return handle_analyze_files(event)
        elif path == '/upload/batch-initiate' and method == 'POST':
            return handle_batch_initiate(event)
        elif path == '/upload/batch-status' and method == 'GET':
            return handle_batch_status(event)
        elif path == '/upload/presigned' and method == 'POST':
            return handle_presigned_url(event)
        elif path == '/upload/deduplication-check' and method == 'POST':
            return handle_deduplication_check(event)
        else:
            return cors_response({'error': 'Endpoint not found'}, 404)
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return cors_response({'error': 'Internal server error'}, 500)

def handle_analyze_files(event) -> Dict[str, Any]:
    """Analyze files for deduplication and strategy selection"""
    try:
        body = json.loads(event.get('body', '{}'))
        files = body.get('files', [])
        user_id = extract_user_id(event)
        
        if not files:
            return cors_response({'error': 'No files provided'}, 400)
        
        logger.info(f"Analyzing {len(files)} files for user {user_id}")
        
        # Analyze each file
        analysis_results = []
        total_size = 0
        duplicates = 0
        
        for file_info in files:
            filename = file_info.get('filename', '')
            size = file_info.get('size', 0)
            file_hash = file_info.get('hash', '')
            content_type = file_info.get('contentType', '')
            
            # Check for duplicates if hash provided
            is_duplicate = False
            if ENABLE_DEDUPLICATION and file_hash:
                is_duplicate = check_duplicate_exists(user_id, file_hash)
            
            # Determine if compression needed
            needs_compression = (
                ENABLE_COMPRESSION and 
                size > COMPRESSION_THRESHOLD and 
                content_type.startswith('image/')
            )
            
            analysis_result = {
                'filename': filename,
                'size': size,
                'hash': file_hash,
                'contentType': content_type,
                'isDuplicate': is_duplicate,
                'needsCompression': needs_compression,
                'estimatedCompressedSize': int(size * 0.6) if needs_compression else size
            }
            
            analysis_results.append(analysis_result)
            
            if not is_duplicate:
                total_size += size
            else:
                duplicates += 1
        
        # Select upload strategy
        unique_files = len(files) - duplicates
        strategy = select_upload_strategy(unique_files, total_size)
        
        # Calculate savings
        bandwidth_savings = sum(
            f['size'] - f['estimatedCompressedSize'] 
            for f in analysis_results 
            if f['needsCompression']
        )
        
        deduplication_savings = sum(
            f['size'] for f in analysis_results if f['isDuplicate']
        )
        
        response = {
            'analysis': analysis_results,
            'strategy': strategy,
            'summary': {
                'totalFiles': len(files),
                'uniqueFiles': unique_files,
                'duplicates': duplicates,
                'totalSize': sum(f['size'] for f in files),
                'uniqueSize': total_size,
                'bandwidthSavings': bandwidth_savings,
                'deduplicationSavings': deduplication_savings,
                'totalSavings': bandwidth_savings + deduplication_savings
            }
        }
        
        return cors_response(response, 200)
        
    except Exception as e:
        logger.error(f"Error in handle_analyze_files: {str(e)}")
        return cors_response({'error': str(e)}, 500)

def handle_batch_initiate(event) -> Dict[str, Any]:
    """Initiate batch upload with enhanced features"""
    try:
        body = json.loads(event.get('body', '{}'))
        files = body.get('files', [])
        user_id = extract_user_id(event)
        strategy = body.get('strategy', {})
        
        if not files:
            return cors_response({'error': 'No files provided'}, 400)
        
        logger.info(f"Initiating batch upload for {len(files)} files, user: {user_id}")
        
        # Filter out duplicates if deduplication enabled
        if ENABLE_DEDUPLICATION:
            files = [f for f in files if not f.get('isDuplicate', False)]
        
        if not files:
            return cors_response({
                'message': 'All files are duplicates',
                'upload_urls': [],
                'batch_id': None,
                'duplicates_skipped': len(body.get('files', []))
            }, 200)
        
        # Determine processing approach
        if strategy.get('type') == 'parallel_simple' or len(files) <= 100:
            return handle_simple_batch(files, user_id, strategy)
        else:
            return handle_enterprise_batch(files, user_id, strategy)
            
    except Exception as e:
        logger.error(f"Error in handle_batch_initiate: {str(e)}")
        return cors_response({'error': str(e)}, 500)

def handle_simple_batch(files: List[Dict], user_id: str, strategy: Dict) -> Dict[str, Any]:
    """Handle simple batch upload (1-100 files)"""
    batch_id = str(uuid.uuid4())
    upload_urls = []
    
    try:
        # Generate presigned URLs for all files
        for file_info in files:
            filename = file_info.get('filename', '')
            content_type = file_info.get('contentType', 'application/octet-stream')
            size = file_info.get('size', 0)
            
            # Generate S3 key with date organization
            s3_key = generate_s3_key(user_id, filename)
            
            # Determine upload type based on size
            upload_type = 'multipart' if size > 100 * 1024 * 1024 else 'simple'  # 100MB threshold
            
            if upload_type == 'simple':
                # Generate simple presigned URL
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
            else:
                # Initiate multipart upload
                multipart_response = s3_client.create_multipart_upload(
                    Bucket=BUCKET_NAME,
                    Key=s3_key,
                    ContentType=content_type
                )
                
                upload_id = multipart_response['UploadId']
                
                # Generate presigned URLs for parts (assuming 10MB parts)
                part_size = 10 * 1024 * 1024  # 10MB
                num_parts = (size + part_size - 1) // part_size
                
                part_urls = []
                for part_num in range(1, min(num_parts + 1, 11)):  # Max 10 parts for demo
                    part_url = s3_client.generate_presigned_url(
                        'upload_part',
                        Params={
                            'Bucket': BUCKET_NAME,
                            'Key': s3_key,
                            'PartNumber': part_num,
                            'UploadId': upload_id
                        },
                        ExpiresIn=3600
                    )
                    part_urls.append({
                        'part_number': part_num,
                        'upload_url': part_url
                    })
                
                upload_urls.append({
                    'filename': filename,
                    'upload_type': 'multipart',
                    'upload_id': upload_id,
                    's3_key': s3_key,
                    'content_type': content_type,
                    'part_urls': part_urls
                })
        
        # Store batch info in DynamoDB
        batch_table.put_item(
            Item={
                'batch_id': batch_id,
                'user_id': user_id,
                'status': 'initiated',
                'total_files': len(files),
                'processed_files': 0,
                'upload_urls': upload_urls,
                'strategy': strategy,
                'created_at': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(hours=24)).timestamp())
            }
        )
        
        logger.info(f"Simple batch {batch_id} initiated with {len(upload_urls)} URLs")
        
        return cors_response({
            'batch_id': batch_id,
            'upload_urls': upload_urls,
            'strategy': 'simple_batch',
            'parallel_streams': strategy.get('streams', MAX_PARALLEL_STREAMS)
        }, 200)
        
    except Exception as e:
        logger.error(f"Error in handle_simple_batch: {str(e)}")
        raise

def handle_enterprise_batch(files: List[Dict], user_id: str, strategy: Dict) -> Dict[str, Any]:
    """Handle enterprise batch upload (1000+ files)"""
    master_batch_id = str(uuid.uuid4())
    batch_size = strategy.get('batchSize', 50)
    
    try:
        # Split files into chunks
        file_chunks = [files[i:i + batch_size] for i in range(0, len(files), batch_size)]
        
        logger.info(f"Enterprise batch {master_batch_id}: {len(file_chunks)} chunks of {batch_size} files each")
        
        # Process first chunk immediately, queue the rest
        first_chunk = file_chunks[0]
        first_chunk_result = handle_simple_batch(first_chunk, user_id, strategy)
        first_batch_id = first_chunk_result['body']['batch_id'] if isinstance(first_chunk_result.get('body'), dict) else json.loads(first_chunk_result.get('body', '{}'))['batch_id']
        
        # Queue remaining chunks for background processing
        queued_batches = []
        for i, chunk in enumerate(file_chunks[1:], 1):
            chunk_batch_id = f"{master_batch_id}-{i+1}"
            
            # Send to SQS for background processing
            sqs_message = {
                'batch_id': chunk_batch_id,
                'master_batch_id': master_batch_id,
                'user_id': user_id,
                'files': chunk,
                'strategy': strategy,
                'chunk_index': i,
                'total_chunks': len(file_chunks)
            }
            
            # Note: SQS sending would be implemented here
            # For now, we'll store in DynamoDB for polling
            batch_table.put_item(
                Item={
                    'batch_id': chunk_batch_id,
                    'master_batch_id': master_batch_id,
                    'user_id': user_id,
                    'status': 'queued',
                    'total_files': len(chunk),
                    'processed_files': 0,
                    'files': chunk,
                    'strategy': strategy,
                    'chunk_index': i,
                    'total_chunks': len(file_chunks),
                    'created_at': datetime.utcnow().isoformat(),
                    'ttl': int((datetime.utcnow() + timedelta(hours=24)).timestamp())
                }
            )
            
            queued_batches.append(chunk_batch_id)
        
        # Store master batch info
        batch_table.put_item(
            Item={
                'batch_id': master_batch_id,
                'user_id': user_id,
                'status': 'processing',
                'total_files': len(files),
                'processed_files': 0,
                'total_chunks': len(file_chunks),
                'completed_chunks': 0,
                'first_batch_id': first_batch_id,
                'queued_batches': queued_batches,
                'strategy': strategy,
                'created_at': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(hours=24)).timestamp())
            }
        )
        
        return cors_response({
            'master_batch_id': master_batch_id,
            'first_batch': json.loads(first_chunk_result.get('body', '{}')),
            'total_chunks': len(file_chunks),
            'queued_chunks': len(queued_batches),
            'strategy': 'enterprise_batch'
        }, 200)
        
    except Exception as e:
        logger.error(f"Error in handle_enterprise_batch: {str(e)}")
        raise

def handle_batch_status(event) -> Dict[str, Any]:
    """Get batch upload status"""
    try:
        batch_id = event.get('queryStringParameters', {}).get('batch_id')
        if not batch_id:
            return cors_response({'error': 'batch_id parameter required'}, 400)
        
        # Get batch info
        response = batch_table.get_item(Key={'batch_id': batch_id})
        
        if 'Item' not in response:
            return cors_response({'error': 'Batch not found'}, 404)
        
        batch_info = response['Item']
        
        # If it's a master batch, aggregate status from all chunks
        if 'total_chunks' in batch_info and batch_info.get('total_chunks', 0) > 1:
            return get_master_batch_status(batch_info)
        else:
            return cors_response({
                'batch_id': batch_id,
                'status': batch_info.get('status', 'unknown'),
                'total_files': batch_info.get('total_files', 0),
                'processed_files': batch_info.get('processed_files', 0),
                'upload_urls': batch_info.get('upload_urls', []),
                'created_at': batch_info.get('created_at'),
                'strategy': batch_info.get('strategy', {})
            }, 200)
            
    except Exception as e:
        logger.error(f"Error in handle_batch_status: {str(e)}")
        return cors_response({'error': str(e)}, 500)

def handle_presigned_url(event) -> Dict[str, Any]:
    """Generate single presigned URL"""
    try:
        body = json.loads(event.get('body', '{}'))
        filename = body.get('filename', '')
        content_type = body.get('contentType', 'application/octet-stream')
        size = body.get('size', 0)
        user_id = extract_user_id(event)
        
        if not filename:
            return cors_response({'error': 'filename required'}, 400)
        
        # Generate S3 key
        s3_key = generate_s3_key(user_id, filename)
        
        # Generate presigned URL
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': s3_key,
                'ContentType': content_type
            },
            ExpiresIn=3600
        )
        
        return cors_response({
            'upload_url': presigned_url,
            's3_key': s3_key,
            'expires_in': 3600
        }, 200)
        
    except Exception as e:
        logger.error(f"Error in handle_presigned_url: {str(e)}")
        return cors_response({'error': str(e)}, 500)

def handle_deduplication_check(event) -> Dict[str, Any]:
    """Check for duplicate files"""
    try:
        body = json.loads(event.get('body', '{}'))
        hashes = body.get('hashes', [])
        user_id = extract_user_id(event)
        
        if not hashes:
            return cors_response({'error': 'hashes required'}, 400)
        
        duplicates = {}
        for file_hash in hashes:
            duplicates[file_hash] = check_duplicate_exists(user_id, file_hash)
        
        return cors_response({'duplicates': duplicates}, 200)
        
    except Exception as e:
        logger.error(f"Error in handle_deduplication_check: {str(e)}")
        return cors_response({'error': str(e)}, 500)

# Helper functions

def select_upload_strategy(file_count: int, total_size: int) -> Dict[str, Any]:
    """Select optimal upload strategy based on file count and size"""
    if file_count <= 100:
        return {
            'type': 'parallel_simple',
            'streams': min(MAX_PARALLEL_STREAMS, file_count),
            'batching': False,
            'description': f'Parallel upload with {min(MAX_PARALLEL_STREAMS, file_count)} streams'
        }
    elif file_count <= 1000:
        return {
            'type': 'batch_processing',
            'streams': MAX_PARALLEL_STREAMS,
            'batching': True,
            'batchSize': 50,
            'description': f'Batch processing with {MAX_PARALLEL_STREAMS} parallel streams'
        }
    else:
        return {
            'type': 'enterprise_mode',
            'streams': MAX_PARALLEL_STREAMS,
            'batching': True,
            'batchSize': min(100, max(25, file_count // 100)),
            'throttling': True,
            'description': f'Enterprise mode with intelligent batching and throttling'
        }

def check_duplicate_exists(user_id: str, file_hash: str) -> bool:
    """Check if file hash already exists for user"""
    if not ENABLE_DEDUPLICATION or not file_hash:
        return False
    
    try:
        response = dedup_table.query(
            IndexName='hash-index',
            KeyConditionExpression='file_hash = :hash AND user_id = :user_id',
            ExpressionAttributeValues={
                ':hash': file_hash,
                ':user_id': user_id
            },
            Limit=1
        )
        
        return len(response.get('Items', [])) > 0
        
    except Exception as e:
        logger.warning(f"Error checking duplicate: {str(e)}")
        return False

def generate_s3_key(user_id: str, filename: str) -> str:
    """Generate S3 key with date-based organization"""
    now = datetime.utcnow()
    year = now.strftime('%Y')
    month = now.strftime('%m')
    
    # Clean filename
    clean_filename = filename.replace(' ', '_').replace('(', '').replace(')', '')
    
    return f"{user_id}/originals/{year}/{month}/{clean_filename}"

def get_master_batch_status(master_batch: Dict) -> Dict[str, Any]:
    """Get aggregated status for master batch"""
    master_batch_id = master_batch['batch_id']
    
    # Query all chunks
    response = batch_table.scan(
        FilterExpression='master_batch_id = :master_id',
        ExpressionAttributeValues={':master_id': master_batch_id}
    )
    
    chunks = response.get('Items', [])
    
    total_files = sum(chunk.get('total_files', 0) for chunk in chunks)
    processed_files = sum(chunk.get('processed_files', 0) for chunk in chunks)
    completed_chunks = sum(1 for chunk in chunks if chunk.get('status') == 'completed')
    
    # Determine overall status
    if completed_chunks == len(chunks):
        status = 'completed'
    elif any(chunk.get('status') == 'failed' for chunk in chunks):
        status = 'failed'
    else:
        status = 'processing'
    
    return cors_response({
        'batch_id': master_batch_id,
        'status': status,
        'total_files': total_files,
        'processed_files': processed_files,
        'total_chunks': len(chunks),
        'completed_chunks': completed_chunks,
        'progress_percentage': (processed_files / total_files * 100) if total_files > 0 else 0,
        'chunks': [
            {
                'batch_id': chunk['batch_id'],
                'status': chunk.get('status', 'unknown'),
                'files': chunk.get('total_files', 0),
                'processed': chunk.get('processed_files', 0)
            }
            for chunk in chunks
        ]
    }, 200)

def extract_user_id(event) -> str:
    """Extract user ID from JWT token or use demo user"""
    # For demo purposes, return a test user ID
    # In production, this would extract from JWT token
    auth_header = event.get('headers', {}).get('Authorization', '')
    if auth_header:
        # TODO: Decode JWT and extract user ID
        pass
    
    return 'demo-user-google-photos'

def cors_response(body: Any, status_code: int = 200) -> Dict[str, Any]:
    """Return response with CORS headers"""
    return {
        'statusCode': status_code,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Amz-Date, X-Api-Key, X-Amz-Security-Token',
            'Content-Type': 'application/json'
        },
        'body': json.dumps(body) if isinstance(body, (dict, list)) else str(body)
    }
