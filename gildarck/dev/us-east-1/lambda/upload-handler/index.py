import json
import boto3
import uuid
import os
from datetime import datetime
from urllib.parse import unquote_plus

s3 = boto3.client('s3')
sqs = boto3.client('sqs')
BUCKET_NAME = os.environ['S3_BUCKET']
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

# Supported file types
SUPPORTED_EXTENSIONS = {
    'image': ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'],
    'video': ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv'],
    'document': ['pdf', 'doc', 'docx', 'txt', 'rtf']
}

def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event, default=str)}")
        
        # Extract user ID from authorizer
        user_id = event.get('requestContext', {}).get('authorizer', {}).get('sub')
        if not user_id:
            return error_response(401, 'Unauthorized - Missing user ID')
        
        http_method = event['httpMethod']
        path = event['path']
        
        print(f"Processing: {http_method} {path} for user {user_id}")
        
        if http_method == 'POST' and path == '/upload/initiate':
            return initiate_multipart_upload(event, user_id)
        elif http_method == 'POST' and path == '/upload/complete':
            return complete_multipart_upload(event, user_id)
        elif http_method == 'GET' and '/upload/presigned' in path:
            return get_presigned_url(event, user_id)
        else:
            return error_response(404, f'Endpoint not found: {http_method} {path}')
            
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        return error_response(500, f'Internal server error: {str(e)}')

def error_response(status_code, message):
    return {
        'statusCode': status_code,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps({'error': message})
    }

def success_response(data):
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(data)
    }

def validate_file(filename, file_size):
    """Validate file type and size"""
    if not filename:
        raise ValueError("Filename is required")
    
    # Check file extension
    file_extension = filename.split('.')[-1].lower() if '.' in filename else ''
    if not file_extension:
        raise ValueError("File must have an extension")
    
    # Check if extension is supported
    supported = False
    for file_type, extensions in SUPPORTED_EXTENSIONS.items():
        if file_extension in extensions:
            supported = True
            break
    
    if not supported:
        raise ValueError(f"Unsupported file type: {file_extension}")
    
    # Check file size (max 5GB for videos, 100MB for others)
    if file_extension in ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv']:
        max_size = 5 * 1024 * 1024 * 1024  # 5GB for videos
    else:
        max_size = 100 * 1024 * 1024  # 100MB for images/documents
    if file_size > max_size:
        raise ValueError(f"File too large: {file_size} bytes (max: {max_size})")
    
    return file_extension

def initiate_multipart_upload(event, user_id):
    try:
        body = json.loads(event['body'])
        print(f"Initiate upload body: {body}")
        
        filename = body.get('filename')
        content_type = body.get('contentType', 'application/octet-stream')
        file_size = body.get('fileSize', 0)
        
        # Validate input
        file_extension = validate_file(filename, file_size)
        
        file_id = str(uuid.uuid4())
        
        # Create temp path for initial upload
        temp_key = f"{user_id}/temp/{file_id}.{file_extension}"
        
        # Calculate chunk size (5MB) and number of parts
        chunk_size = 5 * 1024 * 1024  # 5MB
        total_parts = max(1, (file_size + chunk_size - 1) // chunk_size)
        
        print(f"Creating multipart upload: bucket={BUCKET_NAME}, key={temp_key}")
        
        response = s3.create_multipart_upload(
            Bucket=BUCKET_NAME,
            Key=temp_key,
            ContentType=content_type,
            Metadata={
                'original-filename': filename,
                'user-id': user_id,
                'file-id': file_id,
                'upload-timestamp': datetime.now().isoformat()
            }
        )
        
        result = {
            'uploadId': response['UploadId'],
            'key': temp_key,
            'fileId': file_id,
            'chunkSize': chunk_size,
            'totalParts': total_parts,
            'message': 'Multipart upload initiated successfully'
        }
        
        print(f"Upload initiated successfully: {result}")
        return success_response(result)
        
    except ValueError as e:
        print(f"Validation error: {str(e)}")
        return error_response(400, str(e))
    except Exception as e:
        print(f"Error initiating upload: {str(e)}")
        return error_response(500, f'Failed to initiate upload: {str(e)}')

def complete_multipart_upload(event, user_id):
    try:
        body = json.loads(event['body'])
        print(f"Complete upload body: {body}")
        
        upload_id = body.get('uploadId')
        key = body.get('key')
        parts = body.get('parts', [])
        file_id = body.get('fileId')
        
        # Validate input
        if not all([upload_id, key, file_id]):
            return error_response(400, 'Missing required fields: uploadId, key, fileId')
        
        if not parts:
            return error_response(400, 'No parts provided')
        
        # Validate user owns this upload
        if not key.startswith(f"{user_id}/"):
            return error_response(403, 'Access denied - invalid key')
        
        # Sort parts by part number
        sorted_parts = sorted(parts, key=lambda x: x['partNumber'])
        
        multipart_upload = {
            'Parts': [
                {
                    'ETag': part['etag'],
                    'PartNumber': part['partNumber']
                }
                for part in sorted_parts
            ]
        }
        
        print(f"Completing multipart upload with {len(multipart_upload['Parts'])} parts")
        
        response = s3.complete_multipart_upload(
            Bucket=BUCKET_NAME,
            Key=key,
            UploadId=upload_id,
            MultipartUpload=multipart_upload
        )
        
        # Send message to SQS for processing (will trigger media processor)
        sqs_message = {
            'user_id': user_id,
            's3_key': key,
            'file_id': file_id,
            'bucket': BUCKET_NAME,
            'event_type': 'file_uploaded',
            'timestamp': datetime.now().isoformat()
        }
        
        print(f"Sending SQS message: {sqs_message}")
        
        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(sqs_message)
        )
        
        result = {
            'message': 'Upload completed successfully',
            'location': response['Location'],
            'fileId': file_id,
            'key': key,
            'etag': response['ETag']
        }
        
        print(f"Upload completed successfully: {result}")
        return success_response(result)
        
    except Exception as e:
        print(f"Error completing upload: {str(e)}")
        return error_response(500, f'Failed to complete upload: {str(e)}')

def get_presigned_url(event, user_id):
    try:
        query_params = event.get('queryStringParameters') or {}
        print(f"Presigned URL query params: {query_params}")
        
        key = query_params.get('key')
        part_number = query_params.get('partNumber')
        upload_id = query_params.get('uploadId')
        
        # Validate input
        if not all([key, part_number, upload_id]):
            return error_response(400, 'Missing required parameters: key, partNumber, uploadId')
        
        try:
            part_number = int(part_number)
        except ValueError:
            return error_response(400, 'partNumber must be an integer')
        
        # Validate user owns this upload
        if not key.startswith(f"{user_id}/"):
            return error_response(403, 'Access denied - invalid key')
        
        print(f"Generating presigned URL for part {part_number}")
        
        presigned_url = s3.generate_presigned_url(
            'upload_part',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': key,
                'PartNumber': part_number,
                'UploadId': upload_id
            },
            ExpiresIn=3600  # 1 hour
        )
        
        result = {
            'presignedUrl': presigned_url,
            'partNumber': part_number,
            'expiresIn': 3600
        }
        
        print(f"Presigned URL generated successfully for part {part_number}")
        return success_response(result)
        
    except Exception as e:
        print(f"Error generating presigned URL: {str(e)}")
        return error_response(500, f'Failed to generate presigned URL: {str(e)}')
