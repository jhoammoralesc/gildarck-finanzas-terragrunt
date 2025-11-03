import json
import boto3
import hashlib
import uuid
from datetime import datetime
from urllib.parse import unquote_plus
from decimal import Decimal
import re

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
rekognition = boto3.client('rekognition')
sqs = boto3.client('sqs')

# Environment variables
SQS_QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-thumbnail-queue'

def extract_exif_date(bucket, key):
    """Extract date from EXIF data and filename patterns"""
    try:
        # Get object metadata first
        response = s3.head_object(Bucket=bucket, Key=key)
        
        # Check if we can get creation date from S3 metadata
        if 'Metadata' in response:
            metadata = response['Metadata']
            if 'creation-date' in metadata:
                return datetime.fromisoformat(metadata['creation-date'])
        
        # Try to extract date from filename patterns (common camera formats)
        filename = key.split('/')[-1]
        
        # Enhanced date patterns for common camera/phone formats
        date_patterns = [
            r'IMG_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})',  # IMG_YYYYMMDD_HHMMSS
            r'(\d{4})-(\d{2})-(\d{2})[T_\s](\d{2})[:-](\d{2})[:-](\d{2})',  # YYYY-MM-DD HH:MM:SS
            r'(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})',      # YYYYMMDD_HHMMSS
            r'IMG_(\d{4})(\d{2})(\d{2})',                        # IMG_YYYYMMDD
            r'(\d{4})-(\d{2})-(\d{2})',                          # YYYY-MM-DD
            r'(\d{4})(\d{2})(\d{2})',                            # YYYYMMDD
            r'Screenshot.*(\d{4})-(\d{2})-(\d{2})',              # Screenshot YYYY-MM-DD
        ]
        
        for pattern in date_patterns:
            match = re.search(pattern, filename)
            if match:
                groups = match.groups()
                try:
                    if len(groups) >= 6:  # Full datetime
                        year, month, day, hour, minute, second = map(int, groups[:6])
                        extracted_date = datetime(year, month, day, hour, minute, second)
                    elif len(groups) >= 3:  # Date only
                        year, month, day = map(int, groups[:3])
                        extracted_date = datetime(year, month, day)
                    else:
                        continue
                    
                    # Validate date ranges
                    if 2000 <= year <= 2030 and 1 <= month <= 12 and 1 <= day <= 31:
                        print(f"Extracted date from filename: {extracted_date}")
                        return extracted_date
                except ValueError:
                    continue
        
        print("No valid date found in filename or metadata")
        return None
        
    except Exception as e:
        print(f"Error extracting EXIF date: {str(e)}")
        return None

def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event, indent=2)}")
        
        # Handle EventBridge event format
        if 'detail' in event:
            bucket = event['detail']['bucket']['name']
            key = unquote_plus(event['detail']['object']['key'])
            print(f"Processing: bucket={bucket}, key={key}")
        else:
            print("Invalid event format")
            return {'statusCode': 400, 'body': 'Invalid event format'}
        
        # Check if this is a temp file that needs reorganization
        if '/temp/' in key:
            return process_temp_file(bucket, key)
        else:
            # Regular processing for already organized files
            return process_organized_file(bucket, key)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

def process_temp_file(bucket, temp_key):
    """Process file in temp location and move to proper date-based location"""
    print(f"Processing temp file: {temp_key}")
    
    # Extract user_id and file info
    path_parts = temp_key.split('/')
    user_id = path_parts[0]
    filename = path_parts[-1]
    file_id = filename.split('.')[0]
    extension = filename.split('.')[-1].lower() if '.' in filename else ''
    
    # Download file to extract EXIF (simplified - no PIL for now)
    file_obj = s3.get_object(Bucket=bucket, Key=temp_key)
    file_content = file_obj['Body'].read()
    
    # Try to extract EXIF date
    actual_date = extract_exif_date(bucket, temp_key)
    
    # Use EXIF date if available, otherwise use current date
    if actual_date:
        year = actual_date.year
        month = f"{actual_date.month:02d}"
        print(f"Using EXIF date: {year}-{month} from {actual_date}")
    else:
        actual_date = datetime.now()
        year = actual_date.year
        month = f"{actual_date.month:02d}"
        print(f"No EXIF date found, using current date: {year}-{month}")
    
    # Create final organized path
    final_key = f"{user_id}/originals/{year}/{month}/{file_id}.{extension}"
    
    print(f"Moving from temp: {temp_key} -> {final_key}")
    print(f"Organized by date: {actual_date.isoformat()}")
    
    # Copy to final location
    s3.copy_object(
        Bucket=bucket,
        CopySource={'Bucket': bucket, 'Key': temp_key},
        Key=final_key,
        Metadata={
            'original-filename': filename,
            'user-id': user_id,
            'file-id': file_id,
            'actual-date': actual_date.isoformat(),
            'upload-date': datetime.now().isoformat(),
            'status': 'organized'
        },
        MetadataDirective='REPLACE'
    )
    
    # Delete temp file
    s3.delete_object(Bucket=bucket, Key=temp_key)
    
    # Process the organized file
    return process_organized_file(bucket, final_key, file_content, actual_date)

def process_organized_file(bucket, key, file_content=None, actual_date=None):
    """Process file in final organized location"""
    print(f"Processing organized file: {key}")
    
    # Skip thumbnail files - they don't need processing
    path_parts = key.split('/')
    if len(path_parts) >= 2 and path_parts[1] in ['thumbnails', 'compressed', 'trash']:
        print(f"Skipping non-original file: {key}")
        return {'statusCode': 200, 'body': 'Skipped non-original file'}
    
    # Extract info from organized path
    if len(path_parts) < 5 or path_parts[1] != 'originals':
        print(f"Invalid organized path: {key}")
        return {'statusCode': 400, 'body': 'Invalid organized path'}
    
    user_id = path_parts[0]
    year = path_parts[2]
    month = path_parts[3]
    filename = path_parts[-1]
    file_id = filename.split('.')[0]
    extension = filename.split('.')[-1].lower() if '.' in filename else ''
    
    # Get file content if not provided
    if not file_content:
        file_obj = s3.get_object(Bucket=bucket, Key=key)
        file_content = file_obj['Body'].read()
        response = s3.head_object(Bucket=bucket, Key=key)
        file_size = response['ContentLength']
        content_type = response.get('ContentType', 'unknown')
    else:
        file_size = len(file_content)
        content_type = 'image/jpeg' if extension in ['jpg', 'jpeg'] else 'unknown'
    
    # Calculate hash
    file_hash = hashlib.sha256(file_content).hexdigest()
    
    # Determine media type (improved detection)
    image_extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif']
    video_extensions = ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', 'm4v']
    
    if content_type.startswith('image/') or extension.lower() in image_extensions:
        media_type = 'image'
    elif content_type.startswith('video/') or extension.lower() in video_extensions:
        media_type = 'video'
    else:
        media_type = 'document'
    
    # AI analysis for images
    ai_analysis = {}
    if media_type == 'image':
        try:
            print("Starting AI analysis...")
            labels_response = rekognition.detect_labels(
                Image={'S3Object': {'Bucket': bucket, 'Name': key}},
                MaxLabels=20, MinConfidence=70
            )
            ai_analysis['labels'] = [{'name': l['Name'], 'confidence': Decimal(str(l['Confidence']))} 
                                   for l in labels_response['Labels']]
            
            faces_response = rekognition.detect_faces(
                Image={'S3Object': {'Bucket': bucket, 'Name': key}},
                Attributes=['ALL']
            )
            ai_analysis['faces_count'] = len(faces_response['FaceDetails'])
            print(f"AI analysis completed: {len(ai_analysis.get('labels', []))} labels, {ai_analysis.get('faces_count', 0)} faces")
        except Exception as ai_error:
            print(f"AI analysis failed: {str(ai_error)}")
            ai_analysis = {}
    
    # Generate file paths
    upload_date = actual_date or datetime.now()
    file_paths = get_file_paths(user_id, file_id, extension, upload_date)
    
    # Store metadata
    table = dynamodb.Table('gildarck-media-metadata-dev')
    
    metadata_item = {
        'file_id': file_id,
        'user_id': user_id,
        'original_filename': filename,
        's3_paths': file_paths,
        'file_hash': file_hash,
        'file_size': file_size,
        'content_type': content_type,
        'media_type': media_type,
        'upload_date': upload_date.isoformat(),
        'processing_status': 'completed',
        'ai_analysis': ai_analysis,
        'file_info': {
            'bucket': bucket,
            'size_mb': Decimal(str(round(file_size / (1024 * 1024), 2))),
            'extension': extension,
            'year': year,
            'month': month,
            'organized_by_exif': actual_date is not None
        },
        'organization': {
            'album': None,
            'tags': [],
            'favorite': False,
            'archived': False
        },
        'location': {
            'gps_coordinates': None,
            'address': None,
            'city': None,
            'country': None
        },
        'camera_data': {
            'make': None,
            'model': None,
            'settings': {}
        },
        'thumbnails': {
            'small': file_paths['thumbnails']['small'],
            'medium': file_paths['thumbnails']['medium'],
            'large': file_paths['thumbnails']['large']
        }
    }
    
    table.put_item(Item=metadata_item)
    print(f"Successfully stored metadata for file {file_id}")
    
    # Trigger thumbnail generation for images
    if media_type == 'image':
        trigger_thumbnail_generation(user_id, key, file_id)
    
    return {'statusCode': 200, 'body': 'Media processed and organized successfully'}

def get_file_paths(user_id, file_id, extension, upload_date):
    """Generate Google Photos-like file paths"""
    year = upload_date.year
    month = f"{upload_date.month:02d}"
    
    return {
        'original': f"{user_id}/originals/{year}/{month}/{file_id}.{extension}",
        'thumbnails': {
            'small': f"{user_id}/thumbnails/small/{file_id}_s.webp",
            'medium': f"{user_id}/thumbnails/medium/{file_id}_m.webp", 
            'large': f"{user_id}/thumbnails/large/{file_id}_l.webp"
        },
        'compressed': f"{user_id}/compressed/{file_id}_compressed.{extension}"
    }

def trigger_thumbnail_generation(user_id, s3_key, file_id):
    """Send message to SQS to trigger thumbnail generation"""
    try:
        message = {
            'user_id': user_id,
            's3_key': s3_key,
            'file_id': file_id,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message),
            MessageAttributes={
                'user_id': {
                    'StringValue': user_id,
                    'DataType': 'String'
                },
                'file_id': {
                    'StringValue': file_id,
                    'DataType': 'String'
                }
            }
        )
        
        print(f"Sent thumbnail generation message for {file_id}: {response['MessageId']}")
        return True
        
    except Exception as e:
        print(f"Error sending thumbnail generation message: {str(e)}")
        return False
