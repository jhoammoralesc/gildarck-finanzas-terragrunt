import json
import boto3
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
BUCKET_NAME = os.environ['S3_BUCKET']

def lambda_handler(event, context):
    try:
        processed_count = 0
        
        for record in event['Records']:
            message = json.loads(record['body'])
            
            user_id = message['user_id']
            s3_key = message['s3_key']
            file_id = message['file_id']
            
            logger.info(f"Processing thumbnails for: {s3_key}")
            
            # Check if it's an image file
            if is_image_file(s3_key):
                success = create_thumbnail_placeholders(user_id, s3_key, file_id)
                if success:
                    processed_count += 1
                    logger.info(f"Successfully created thumbnail placeholders for {s3_key}")
                else:
                    logger.error(f"Failed to create thumbnail placeholders for {s3_key}")
            else:
                logger.info(f"Skipping non-image file: {s3_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': processed_count,
                'total': len(event['Records']),
                'message': 'Thumbnail placeholders created (Pillow processing will be added later)'
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing thumbnails: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def is_image_file(s3_key):
    """Check if file is a supported image format"""
    image_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff']
    return any(s3_key.lower().endswith(ext) for ext in image_extensions)

def create_thumbnail_placeholders(user_id, s3_key, file_id):
    """Create thumbnail placeholders - will be replaced with real thumbnails later"""
    try:
        # Get original file info
        response = s3.head_object(Bucket=BUCKET_NAME, Key=s3_key)
        content_type = response.get('ContentType', 'image/jpeg')
        
        # Thumbnail configurations
        thumbnail_configs = {
            'small': {'size': '150x150', 'path': f"{user_id}/thumbnails/small/{file_id}_s.webp"},
            'medium': {'size': '300x300', 'path': f"{user_id}/thumbnails/medium/{file_id}_m.webp"},
            'large': {'size': '800x800', 'path': f"{user_id}/thumbnails/large/{file_id}_l.webp"}
        }
        
        # Create placeholder thumbnails
        for size_name, config in thumbnail_configs.items():
            # Create a placeholder content indicating thumbnail generation is pending
            placeholder_content = f"THUMBNAIL_PLACEHOLDER_{size_name.upper()}_{config['size']}_FOR_{file_id}"
            
            # Upload placeholder
            s3.put_object(
                Bucket=BUCKET_NAME,
                Key=config['path'],
                Body=placeholder_content.encode(),
                ContentType='text/plain',  # Will be image/webp when real processing is added
                Metadata={
                    'original-file': s3_key,
                    'thumbnail-size': size_name,
                    'dimensions': config['size'],
                    'user-id': user_id,
                    'file-id': file_id,
                    'status': 'placeholder-pending-pillow'
                }
            )
            
            logger.info(f"Created {size_name} thumbnail placeholder: {config['path']}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error creating thumbnail placeholders for {s3_key}: {str(e)}")
        return False
