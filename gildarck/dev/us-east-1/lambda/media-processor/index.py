import json
import boto3
import os
import hashlib
import uuid
from datetime import datetime
from PIL import Image
from PIL.ExifTags import TAGS
import io

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
rekognition = boto3.client('rekognition')

S3_BUCKET = os.environ['S3_BUCKET']
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    try:
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Extract user_id from S3 key path
            user_id = key.split('/')[0]
            
            # Process the uploaded file
            process_media_file(bucket, key, user_id)
            
        return {'statusCode': 200, 'body': json.dumps('Processing completed')}
    except Exception as e:
        print(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps(f'Error: {str(e)}')}

def process_media_file(bucket, key, user_id):
    # Download file from S3
    response = s3_client.get_object(Bucket=bucket, Key=key)
    file_content = response['Body'].read()
    
    # Generate file hash for deduplication
    file_hash = hashlib.sha256(file_content).hexdigest()
    
    # Check if file already exists (deduplication)
    existing_file = check_duplicate(file_hash)
    if existing_file:
        print(f"Duplicate file found: {file_hash}")
        return
    
    # Extract metadata
    metadata = extract_metadata(file_content, key)
    
    # Generate thumbnails for images
    if metadata['media_type'] == 'image':
        generate_thumbnails(bucket, key, file_content)
    
    # AI analysis with Rekognition
    ai_analysis = analyze_with_rekognition(bucket, key, metadata['media_type'])
    
    # Save metadata to DynamoDB
    save_metadata(user_id, file_hash, key, metadata, ai_analysis)

def extract_metadata(file_content, key):
    metadata = {
        'file_id': str(uuid.uuid4()),
        'filename': key.split('/')[-1],
        'file_size': len(file_content),
        's3_key': key,
        'created_date': datetime.utcnow().isoformat(),
        'upload_date': datetime.utcnow().isoformat(),
        'media_type': get_media_type(key),
        'category': get_category_from_path(key)
    }
    
    # Extract EXIF data for images
    if metadata['media_type'] == 'image':
        try:
            image = Image.open(io.BytesIO(file_content))
            metadata['width'] = image.width
            metadata['height'] = image.height
            
            exif_data = image._getexif()
            if exif_data:
                metadata['camera_info'] = extract_exif_data(exif_data)
        except Exception as e:
            print(f"Error extracting EXIF: {e}")
    
    return metadata

def generate_thumbnails(bucket, key, file_content):
    try:
        image = Image.open(io.BytesIO(file_content))
        sizes = {'small': 150, 'medium': 500, 'large': 1000}
        
        for size_name, size in sizes.items():
            # Create thumbnail
            thumbnail = image.copy()
            thumbnail.thumbnail((size, size), Image.Resampling.LANCZOS)
            
            # Save thumbnail to S3
            thumb_buffer = io.BytesIO()
            thumbnail.save(thumb_buffer, format='JPEG', quality=85)
            thumb_buffer.seek(0)
            
            thumb_key = key.replace('/media/', f'/thumbnails/{size_name}/')
            s3_client.put_object(
                Bucket=bucket,
                Key=thumb_key,
                Body=thumb_buffer.getvalue(),
                ContentType='image/jpeg'
            )
    except Exception as e:
        print(f"Error generating thumbnails: {e}")

def analyze_with_rekognition(bucket, key, media_type):
    if media_type != 'image':
        return {}
    
    try:
        # Detect labels
        labels_response = rekognition.detect_labels(
            Image={'S3Object': {'Bucket': bucket, 'Name': key}},
            MaxLabels=10,
            MinConfidence=70
        )
        
        # Detect faces
        faces_response = rekognition.detect_faces(
            Image={'S3Object': {'Bucket': bucket, 'Name': key}},
            Attributes=['ALL']
        )
        
        return {
            'objects': [{'label': label['Name'], 'confidence': label['Confidence']} 
                       for label in labels_response['Labels']],
            'faces': [{'confidence': face['Confidence'], 
                      'bounding_box': face['BoundingBox']} 
                     for face in faces_response['FaceDetails']]
        }
    except Exception as e:
        print(f"Error with Rekognition: {e}")
        return {}

def save_metadata(user_id, file_hash, key, metadata, ai_analysis):
    item = {
        'user_id': user_id,
        'file_id': metadata['file_id'],
        'file_hash': file_hash,
        **metadata,
        'ai_analysis': ai_analysis,
        'processing_status': 'completed'
    }
    
    table.put_item(Item=item)

def check_duplicate(file_hash):
    try:
        response = table.query(
            IndexName='FileHashIndex',
            KeyConditionExpression='file_hash = :hash',
            ExpressionAttributeValues={':hash': file_hash}
        )
        return len(response['Items']) > 0
    except:
        return False

def get_media_type(key):
    ext = key.lower().split('.')[-1]
    if ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']:
        return 'image'
    elif ext in ['mp4', 'mov', 'avi', 'mkv']:
        return 'video'
    else:
        return 'document'

def get_category_from_path(key):
    if '/images/' in key:
        return 'images'
    elif '/videos/' in key:
        return 'videos'
    elif '/documents/' in key:
        return 'documents'
    elif '/trash/' in key:
        return 'trash'
    return 'unknown'

def extract_exif_data(exif_data):
    camera_info = {}
    for tag_id, value in exif_data.items():
        tag = TAGS.get(tag_id, tag_id)
        if tag in ['Make', 'Model', 'FocalLength', 'FNumber', 'ISOSpeedRatings']:
            camera_info[tag.lower()] = str(value)
    return camera_info
