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

def generate_file_id():
    """Generate unique file ID like Google Photos"""
    return str(uuid.uuid4())

def get_file_paths(cognito_sub, file_id, extension, upload_date):
    """Generate Google Photos-like file paths"""
    year = upload_date.year
    month = f"{upload_date.month:02d}"
    
    return {
        'original': f"{cognito_sub}/originals/{year}/{month}/{file_id}.{extension}",
        'thumbnails': {
            'small': f"{cognito_sub}/thumbnails/small/{file_id}_s.webp",
            'medium': f"{cognito_sub}/thumbnails/medium/{file_id}_m.webp", 
            'large': f"{cognito_sub}/thumbnails/large/{file_id}_l.webp"
        },
        'compressed': f"{cognito_sub}/compressed/{file_id}_compressed.{extension}"
    }

def lambda_handler(event, context):
    try:
        # Debug: Log the entire event
        print(f"Received event: {json.dumps(event, indent=2)}")
        
        # Handle EventBridge event format
        if 'detail' in event:
            print("Processing EventBridge event")
            bucket = event['detail']['bucket']['name']
            key = unquote_plus(event['detail']['object']['key'])
            print(f"Extracted from EventBridge: bucket={bucket}, key={key}")
        else:
            print("Invalid event format - no 'detail' key found")
            return {'statusCode': 400, 'body': 'Invalid event format'}
        
        # Extract cognito_sub from S3 key: {cognito-sub}/originals/{year}/{month}/{file-id}.{ext}
        path_parts = key.split('/')
        print(f"Path parts: {path_parts}")
        
        if len(path_parts) < 5 or path_parts[1] != 'originals':
            print(f"Invalid S3 key structure. Expected format: cognito-sub/originals/year/month/filename")
            return {'statusCode': 400, 'body': 'Invalid S3 key structure'}
        
        cognito_sub = path_parts[0]
        year = path_parts[2]
        month = path_parts[3]
        filename = path_parts[-1]
        
        print(f"Extracted: cognito_sub={cognito_sub}, year={year}, month={month}, filename={filename}")
        
        # Extract file_id and extension
        file_id = filename.split('.')[0]
        extension = filename.split('.')[-1].lower() if '.' in filename else ''
        
        print(f"File details: file_id={file_id}, extension={extension}")
        
        # Get file metadata from S3
        response = s3.head_object(Bucket=bucket, Key=key)
        file_size = response['ContentLength']
        content_type = response.get('ContentType', 'unknown')
        
        print(f"S3 metadata: size={file_size}, content_type={content_type}")
        
        # Download file to calculate hash
        file_obj = s3.get_object(Bucket=bucket, Key=key)
        file_content = file_obj['Body'].read()
        file_hash = hashlib.sha256(file_content).hexdigest()
        
        print(f"File hash calculated: {file_hash}")
        
        # Determine media type
        media_type = 'image' if content_type.startswith('image/') else \
                    'video' if content_type.startswith('video/') else 'document'
        
        print(f"Media type determined: {media_type}")
        
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
        upload_date = datetime.now()
        file_paths = get_file_paths(cognito_sub, file_id, extension, upload_date)
        
        print(f"Generated file paths: {json.dumps(file_paths, indent=2)}")
        
        # Store metadata with Google Photos-like structure
        table = dynamodb.Table('gildarck-media-metadata-dev')
        
        metadata_item = {
            'file_id': file_id,
            'user_id': cognito_sub,
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
                'month': month
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
        
        print(f"Storing metadata item: {json.dumps(metadata_item, indent=2, default=str)}")
        
        table.put_item(Item=metadata_item)
        
        print(f"Successfully stored metadata for file {file_id}")
        
        return {'statusCode': 200, 'body': 'Media processed successfully'}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        return {'statusCode': 500, 'body': str(e)}
