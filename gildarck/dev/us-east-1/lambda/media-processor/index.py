import json
import boto3
import hashlib
import uuid
from datetime import datetime
from urllib.parse import unquote_plus
from decimal import Decimal

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
rekognition = boto3.client('rekognition')

def lambda_handler(event, context):
    try:
        # Handle EventBridge event format
        if 'detail' in event:
            bucket = event['detail']['bucket']['name']
            key = unquote_plus(event['detail']['object']['key'])
        else:
            return {'statusCode': 400, 'body': 'Invalid event format'}
        
        # Extract cognito_sub and category from S3 key: {cognito-sub}/media/{category}/{filename}
        path_parts = key.split('/')
        if len(path_parts) < 4 or path_parts[1] != 'media':
            return {'statusCode': 400, 'body': 'Invalid S3 key structure'}
        
        cognito_sub = path_parts[0]  # Cognito user sub (UUID)
        category = path_parts[2]     # images, videos, documents, trash
        filename = path_parts[-1]
        
        # Get file metadata from S3
        response = s3.head_object(Bucket=bucket, Key=key)
        file_size = response['ContentLength']
        content_type = response.get('ContentType', 'unknown')
        
        # Download file to calculate hash
        file_obj = s3.get_object(Bucket=bucket, Key=key)
        file_content = file_obj['Body'].read()
        file_hash = hashlib.sha256(file_content).hexdigest()
        
        # Determine media type
        media_type = 'image' if content_type.startswith('image/') else \
                    'video' if content_type.startswith('video/') else 'document'
        
        # AI analysis for images
        ai_analysis = {}
        if media_type == 'image':
            try:
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
            except:
                ai_analysis = {}
        
        # Store metadata with Cognito sub as user_id
        table = dynamodb.Table('gildarck-media-metadata-dev')
        table.put_item(Item={
            'file_id': str(uuid.uuid4()),
            'user_id': cognito_sub,  # Cognito sub UUID
            'filename': filename,
            's3_key': key,
            'file_hash': file_hash,
            'file_size': file_size,
            'content_type': content_type,
            'media_type': media_type,
            'category': category,
            'upload_date': datetime.utcnow().isoformat(),
            'processing_status': 'completed',
            'ai_analysis': ai_analysis,
            'file_info': {
                'bucket': bucket,
                'size_mb': Decimal(str(round(file_size / (1024 * 1024), 2))),
                'extension': filename.split('.')[-1].lower() if '.' in filename else ''
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
                'small': None,
                'medium': None,
                'large': None
            }
        })
        
        return {'statusCode': 200, 'body': 'Media processed successfully'}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': str(e)}
