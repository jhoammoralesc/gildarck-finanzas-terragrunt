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
            
            # Check if it's an image or video file
            if is_image_file(s3_key):
                success = create_image_thumbnails(user_id, s3_key, file_id)
                if success:
                    processed_count += 1
                    logger.info(f"Successfully created image thumbnails for {s3_key}")
                else:
                    logger.error(f"Failed to create image thumbnails for {s3_key}")
            elif is_video_file(s3_key):
                success = create_video_thumbnails(user_id, s3_key, file_id)
                if success:
                    processed_count += 1
                    logger.info(f"Successfully created video thumbnails for {s3_key}")
                else:
                    logger.error(f"Failed to create video thumbnails for {s3_key}")
            else:
                logger.info(f"Skipping unsupported file: {s3_key}")
        
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

def is_video_file(s3_key):
    """Check if file is a supported video format"""
    video_extensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v']
    return any(s3_key.lower().endswith(ext) for ext in video_extensions)

def create_image_thumbnails(user_id, s3_key, file_id):
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
                # Create thumbnail with crop to fill (like Google Photos)
                thumbnail = img.copy()
                
                # Calculate crop dimensions to maintain aspect ratio and fill square
                img_width, img_height = thumbnail.size
                target_size = config['size'][0]  # Square thumbnails
                
                # Calculate crop box to center the image
                if img_width > img_height:
                    # Landscape: crop width
                    new_width = int(img_height)
                    left = (img_width - new_width) // 2
                    crop_box = (left, 0, left + new_width, img_height)
                else:
                    # Portrait or square: crop height
                    new_height = int(img_width)
                    top = (img_height - new_height) // 2
                    crop_box = (0, top, img_width, top + new_height)
                
                # Crop to square and resize
                thumbnail = thumbnail.crop(crop_box)
                thumbnail = thumbnail.resize(config['size'], Image.Resampling.LANCZOS)
                
                # Save as WebP directly (no white canvas)
                output_buffer = io.BytesIO()
                thumbnail.save(output_buffer, format='WEBP', quality=85, optimize=True)
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
        logger.error(f"Error creating image thumbnails for {s3_key}: {str(e)}")
        return False

def create_video_thumbnails(user_id, s3_key, file_id):
    """Create better video thumbnails with gradient and play icon"""
    try:
        from PIL import ImageDraw
        
        thumbnail_configs = {
            'small': {'size': (150, 150), 'path': f"{user_id}/thumbnails/small/{file_id}_s.webp"},
            'medium': {'size': (300, 300), 'path': f"{user_id}/thumbnails/medium/{file_id}_m.webp"},
            'large': {'size': (800, 800), 'path': f"{user_id}/thumbnails/large/{file_id}_l.webp"}
        }
        
        for size_name, config in thumbnail_configs.items():
            # Create a gradient background
            img = Image.new('RGB', config['size'], (20, 20, 20))
            draw = ImageDraw.Draw(img)
            
            # Create gradient effect
            width, height = config['size']
            for y in range(height):
                # Gradient from dark to slightly lighter
                color_value = int(20 + (y / height) * 30)
                color = (color_value, color_value, color_value)
                draw.line([(0, y), (width, y)], fill=color)
            
            # Draw play button circle
            center_x, center_y = width // 2, height // 2
            circle_radius = min(width, height) // 6
            
            # Draw circle background
            circle_bbox = [
                center_x - circle_radius,
                center_y - circle_radius,
                center_x + circle_radius,
                center_y + circle_radius
            ]
            draw.ellipse(circle_bbox, fill=(80, 80, 80), outline=(120, 120, 120), width=2)
            
            # Draw play triangle
            triangle_size = circle_radius // 2
            triangle_points = [
                (center_x - triangle_size//2, center_y - triangle_size),
                (center_x - triangle_size//2, center_y + triangle_size),
                (center_x + triangle_size, center_y)
            ]
            draw.polygon(triangle_points, fill=(200, 200, 200))
            
            # Save as WebP
            output_buffer = io.BytesIO()
            img.save(output_buffer, format='WEBP', quality=85, optimize=True)
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
                    'format': 'webp',
                    'type': 'video-thumbnail'
                }
            )
            
            logger.info(f"Created {size_name} video thumbnail: {config['path']}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error creating video thumbnails for {s3_key}: {str(e)}")
        return False
