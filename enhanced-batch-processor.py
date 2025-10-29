import json
import boto3
import os
from datetime import datetime
import time

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

S3_BUCKET = os.environ['S3_BUCKET']
BATCH_TABLE = os.environ.get('BATCH_TABLE', 'gildarck-batch-uploads-dev')
MULTIPART_THRESHOLD = 100 * 1024 * 1024  # 100MB

batch_table = dynamodb.Table(BATCH_TABLE)

def generate_upload_strategy(file_info):
    """Determine upload strategy based on file size"""
    file_size = file_info.get('file_size', 0)
    filename = file_info.get('filename')
    content_type = file_info.get('content_type', 'application/octet-stream')
    
    current_date = datetime.now()
    year = current_date.strftime('%Y')
    month = current_date.strftime('%m')
    
    if file_size < MULTIPART_THRESHOLD:
        # Simple upload
        return {
            'strategy': 'simple',
            'upload_type': 'PUT',
            'filename': filename,
            'content_type': content_type,
            'file_size': file_size
        }
    else:
        # Multipart upload
        chunk_size = 5 * 1024 * 1024  # 5MB
        total_parts = max(1, (file_size + chunk_size - 1) // chunk_size)
        
        return {
            'strategy': 'multipart',
            'upload_type': 'MULTIPART',
            'filename': filename,
            'content_type': content_type,
            'file_size': file_size,
            'chunk_size': chunk_size,
            'total_parts': total_parts
        }

def generate_simple_upload_url(user_id, file_info):
    """Generate presigned URL for simple upload"""
    filename = file_info.get('filename')
    content_type = file_info.get('content_type', 'application/octet-stream')
    
    current_date = datetime.now()
    year = current_date.strftime('%Y')
    month = current_date.strftime('%m')
    
    s3_key = f"{user_id}/originals/{year}/{month}/{filename}"
    
    presigned_url = s3_client.generate_presigned_url(
        'put_object',
        Params={
            'Bucket': S3_BUCKET,
            'Key': s3_key,
            'ContentType': content_type
        },
        ExpiresIn=3600
    )
    
    return {
        'filename': filename,
        'upload_url': presigned_url,
        's3_key': s3_key,
        'upload_type': 'simple'
    }

def generate_multipart_upload_urls(user_id, file_info):
    """Generate multipart upload URLs"""
    filename = file_info.get('filename')
    content_type = file_info.get('content_type', 'application/octet-stream')
    total_parts = file_info.get('total_parts', 1)
    
    current_date = datetime.now()
    year = current_date.strftime('%Y')
    month = current_date.strftime('%m')
    
    s3_key = f"{user_id}/originals/{year}/{month}/{filename}"
    
    # Create multipart upload
    response = s3_client.create_multipart_upload(
        Bucket=S3_BUCKET,
        Key=s3_key,
        ContentType=content_type
    )
    
    upload_id = response['UploadId']
    part_urls = []
    
    # Generate presigned URLs for each part
    for part_number in range(1, total_parts + 1):
        part_url = s3_client.generate_presigned_url(
            'upload_part',
            Params={
                'Bucket': S3_BUCKET,
                'Key': s3_key,
                'PartNumber': part_number,
                'UploadId': upload_id
            },
            ExpiresIn=3600
        )
        
        part_urls.append({
            'part_number': part_number,
            'upload_url': part_url
        })
    
    return {
        'filename': filename,
        'upload_id': upload_id,
        's3_key': s3_key,
        'upload_type': 'multipart',
        'part_urls': part_urls,
        'total_parts': total_parts
    }

def lambda_handler(event, context):
    """Process batch upload requests with smart upload strategy"""
    
    try:
        for record in event['Records']:
            message_body = json.loads(record['body'])
            
            master_batch_id = message_body.get('master_batch_id')
            user_id = message_body.get('user_id')
            files = message_body.get('files', [])
            
            if not all([master_batch_id, user_id, files]):
                print(f"Invalid batch request: missing required fields")
                continue
            
            upload_urls = []
            
            for file_info in files:
                try:
                    # Determine upload strategy
                    strategy = generate_upload_strategy(file_info)
                    
                    if strategy['strategy'] == 'simple':
                        url_info = generate_simple_upload_url(user_id, file_info)
                    else:
                        url_info = generate_multipart_upload_urls(user_id, file_info)
                    
                    upload_urls.append(url_info)
                    print(f"Generated {strategy['strategy']} upload for {file_info.get('filename')}")
                    
                except Exception as e:
                    print(f"Error processing {file_info.get('filename')}: {str(e)}")
                    upload_urls.append({
                        'filename': file_info.get('filename'),
                        'error': str(e)
                    })
            
            # Store results in DynamoDB
            batch_item = {
                'batch_id': master_batch_id,
                'user_id': user_id,
                'status': 'completed',
                'upload_urls': upload_urls,
                'created_at': datetime.now().isoformat(),
                'total_files': len(files),
                'processed_files': len([url for url in upload_urls if 'upload_url' in url or 'part_urls' in url]),
                'ttl': int(time.time()) + 86400
            }
            
            batch_table.put_item(Item=batch_item)
            print(f"Batch {master_batch_id} completed with {len(upload_urls)} URLs")
            
    except Exception as e:
        print(f"Error processing batch: {str(e)}")
        raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Batch processing completed'})
    }
