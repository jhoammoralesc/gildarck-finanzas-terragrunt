import json
import boto3
import os
import sys
import io
import logging

# Pillow will be available via Lambda Layer
from PIL import Image, ImageOps

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
                success = create_thumbnails(user_id, s3_key, file_id)
                if success:
                    processed_count += 1
                    logger.info(f"Successfully created thumbnails for {s3_key}")
                else:
                    logger.error(f"Failed to create thumbnails for {s3_key}")
            else:
                logger.info(f"Skipping non-image file: {s3_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': processed_count,
                'total': len(event['Records']),
                'message': 'Thumbnails generated successfully'
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

def create_thumbnails(user_id, s3_key, file_id):
    """Create actual thumbnails using Pillow"""
    try:
        # Download original image
        response = s3.get_object(Bucket=BUCKET_NAME, Key=s3_key)
        image_data = response['Body'].read()
        
        # Open image with Pillow
        with Image.open(io.BytesIO(image_data)) as img:
            # Convert to RGB if necessary
            if img.mode in ('RGBA', 'LA', 'P'):
                img = img.convert('RGB')
            
            # Thumbnail configurations
            thumbnail_configs = {
                'small': {'size': (150, 150), 'path': f"{user_id}/thumbnails/small/{file_id}_s.webp"},
                'medium': {'size': (300, 300), 'path': f"{user_id}/thumbnails/medium/{file_id}_m.webp"},
                'large': {'size': (800, 800), 'path': f"{user_id}/thumbnails/large/{file_id}_l.webp"}
            }
            
            # Generate each thumbnail
            for size_name, config in thumbnail_configs.items():
                # Create thumbnail maintaining aspect ratio
                thumbnail = img.copy()
                thumbnail.thumbnail(config['size'], Image.Resampling.LANCZOS)
                
                # Create a square canvas and center the image
                canvas = Image.new('RGB', config['size'], (255, 255, 255))
                offset = ((config['size'][0] - thumbnail.width) // 2,
                         (config['size'][1] - thumbnail.height) // 2)
                canvas.paste(thumbnail, offset)
                
                # Save as WebP
                output_buffer = io.BytesIO()
                canvas.save(output_buffer, format='WEBP', quality=85, optimize=True)
                output_buffer.seek(0)
                
                # Upload to S3
                s3.put_object(
                    Bucket=BUCKET_NAME,
                    Key=config['path'],
                    Body=output_buffer.getvalue(),
                    ContentType='image/webp',
                    Metadata={
                        'original-file': s3_key,
                        'thumbnail-size': size_name,
                        'dimensions': f"{config['size'][0]}x{config['size'][1]}",
                        'user-id': user_id,
                        'file-id': file_id,
                        'format': 'webp'
                    }
                )
                
                logger.info(f"Created {size_name} thumbnail: {config['path']}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error creating thumbnails for {s3_key}: {str(e)}")
        return False
