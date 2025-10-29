import json
import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError
from decimal import Decimal

# Custom JSON encoder for Decimal values
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super(DecimalEncoder, self).default(o)

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
table = dynamodb.Table('gildarck-media-metadata-dev')

def extract_cognito_sub(event):
    """Extract cognito sub from API Gateway authorizer context"""
    try:
        # Try different possible paths for Cognito sub
        if 'requestContext' in event and 'authorizer' in event['requestContext']:
            authorizer = event['requestContext']['authorizer']
            
            # Path 1: Direct claims
            if 'claims' in authorizer and 'sub' in authorizer['claims']:
                return authorizer['claims']['sub']
            
            # Path 2: Cognito identity
            if 'sub' in authorizer:
                return authorizer['sub']
                
            # Path 3: Principal ID (sometimes used)
            if 'principalId' in authorizer:
                return authorizer['principalId']
        
        print(f"DEBUG: Full event context: {event.get('requestContext', {})}")
        raise ValueError("Cognito sub not found in request context")
    except Exception as e:
        print(f"Error extracting Cognito sub: {str(e)}")
        raise ValueError("Cognito sub not found in request context")

def lambda_handler(event, context):
    try:
        # Extract user_id (Cognito sub) consistently with other functions
        user_id = extract_cognito_sub(event)
        
        # Handle both proxy and direct path configurations
        path = ""
        resource_path = event.get('resource', '')
        
        if event.get('pathParameters') and event['pathParameters'].get('proxy'):
            path = event['pathParameters']['proxy']
        else:
            # For direct endpoints, extract from resource path
            if resource_path == '/media/list':
                path = 'list'
            elif resource_path == '/media/trash':
                path = 'trash'
            elif resource_path.startswith('/media/thumbnail/'):
                path = resource_path.replace('/media/', '')
            elif resource_path.startswith('/media/file/'):
                path = resource_path.replace('/media/', '')
                # Also check for direct path parameters
                if event.get('pathParameters') and event['pathParameters'].get('file_id'):
                    file_id = event['pathParameters']['file_id']
                    path = f"file/{file_id}"
            elif '/trash' in resource_path:
                path = 'trash'
        
        method = event['httpMethod']
        
        print(f"Processing: {method} {path} for user {user_id}")
        print(f"Resource path: {resource_path}")
        print(f"Path parameters: {event.get('pathParameters', {})}")
        
        if method == 'GET':
            if path == 'list':
                return list_media_chronological(user_id, event.get('queryStringParameters') or {})
            elif path == 'trash':
                return list_trash_items(user_id)
            elif path.startswith('thumbnail/'):
                file_id = path.split('/')[-1]
                return get_thumbnail(user_id, file_id)
            elif path.startswith('file/'):
                file_id = path.split('/')[-1]
                return get_file_details(user_id, file_id)
        
        return {
            'statusCode': 404,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'Not found'})
        }
        
    except Exception as e:
        print(f"Error in media-retrieval: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': str(e)})
        }

def cors_headers():
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    }

def list_media_chronological(user_id, params):
    """List media chronologically like Google Photos - newest first"""
    try:
        # Ensure params is a dict
        if params is None:
            params = {}
        
        limit = int(params.get('limit', 50))
        offset = int(params.get('offset', 0))
        
        # Query all user media
        response = table.query(
            KeyConditionExpression=Key('user_id').eq(user_id)
        )
        
        items = response.get('Items', [])
        
        # Sort chronologically (newest first) by EXIF date or upload_date
        def get_sort_date(item):
            file_info = item.get('file_info', {})
            if file_info.get('year') and file_info.get('month'):
                return f"{file_info['year']}-{str(file_info['month']).zfill(2)}-01"
            return item.get('upload_date', '1970-01-01')
        
        sorted_items = sorted(items, key=get_sort_date, reverse=True)
        
        # Apply pagination
        total_count = len(sorted_items)
        paginated_items = sorted_items[offset:offset + limit]
        
        # Filter out trashed items (only show active media)
        active_items = [item for item in paginated_items if item.get('processing_status') != 'trashed']
        
        # Format for frontend consumption (Google Photos style)
        formatted_items = []
        for item in active_items:
            # Safely get ai_analysis data
            ai_analysis = item.get('ai_analysis') or {}
            labels = ai_analysis.get('labels') or []
            
            # Generate presigned URL for thumbnail
            thumbnail_url = None
            thumbnail_paths = item.get('thumbnails', {})
            if thumbnail_paths.get('medium'):
                try:
                    thumbnail_url = s3.generate_presigned_url(
                        'get_object',
                        Params={'Bucket': 'gildarck-media-dev', 'Key': thumbnail_paths['medium']},
                        ExpiresIn=3600
                    )
                except Exception as e:
                    print(f"Error generating presigned URL for {item.get('file_id')}: {str(e)}")
            
            formatted_item = {
                'file_id': item.get('file_id'),
                'upload_date': item.get('upload_date'),
                'original_filename': item.get('original_filename'),
                'content_type': item.get('content_type'),
                'file_size': item.get('file_size'),
                'thumbnails': thumbnail_paths,
                'thumbnail_url': thumbnail_url,  # Ready-to-use presigned URL
                'ai_analysis': {
                    'labels': [label.get('name') for label in labels if label and isinstance(label, dict)],
                    'faces_count': ai_analysis.get('faces_count', 0)
                },
                'processing_status': item.get('processing_status'),
                'organization': item.get('organization', {}),
                'file_info': item.get('file_info', {})
            }
            formatted_items.append(formatted_item)
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'items': formatted_items,
                'count': len(formatted_items),
                'total_count': len(active_items),  # Only count active items
                'offset': offset,
                'limit': limit,
                'has_more': offset + limit < len(active_items),
                'sorted_by': 'chronological_desc'
            }, cls=DecimalEncoder)
        }
    except Exception as e:
        print(f"Error listing media chronologically for user {user_id}: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': f'Failed to list media: {str(e)}'})
        }

def get_thumbnail(user_id, file_id):
    try:
        response = table.get_item(Key={'user_id': user_id, 'file_id': file_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'File not found'})
            }
        
        item = response['Item']
        
        # Use the thumbnail paths from metadata
        thumbnail_paths = item.get('thumbnails', {})
        medium_thumbnail = thumbnail_paths.get('medium', f"{user_id}/thumbnails/medium/{file_id}_m.webp")
        
        url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': 'gildarck-media-dev', 'Key': medium_thumbnail},
            ExpiresIn=3600
        )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'thumbnail_url': url,
                'file_id': file_id,
                'thumbnails': thumbnail_paths
            })
        }
    except Exception as e:
        print(f"Error getting thumbnail for {file_id}: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': f'Failed to get thumbnail: {str(e)}'})
        }

def get_file_details(user_id, file_id):
    try:
        print(f"Looking up file: user_id={user_id}, file_id={file_id}")
        
        response = table.get_item(Key={'user_id': user_id, 'file_id': file_id})
        
        if 'Item' not in response:
            print(f"File not found in DynamoDB: {file_id}")
            
            # Try to find the file by searching for partial matches
            # This handles cases where the frontend might have stale file IDs
            try:
                query_response = table.query(
                    KeyConditionExpression=Key('user_id').eq(user_id)
                )
                
                items = query_response.get('Items', [])
                print(f"Found {len(items)} total files for user")
                
                # Look for files that contain the requested file_id as a substring
                # This handles cases where the file_id might have UUID prefixes
                matching_files = []
                for item in items:
                    item_file_id = item.get('file_id', '')
                    original_filename = item.get('original_filename', '')
                    
                    # Check if the requested file_id matches any part of the stored data
                    if (file_id in item_file_id or 
                        file_id in original_filename or
                        item_file_id.endswith(file_id.split('_', 1)[-1] if '_' in file_id else file_id)):
                        matching_files.append(item)
                        print(f"Found potential match: {item_file_id}")
                
                if matching_files:
                    # Use the first match
                    item = matching_files[0]
                    print(f"Using matched file: {item.get('file_id')}")
                else:
                    return {
                        'statusCode': 404,
                        'headers': cors_headers(),
                        'body': json.dumps({
                            'error': 'File not found',
                            'requested_file_id': file_id,
                            'user_id': user_id,
                            'available_files': [item.get('file_id') for item in items[:5]]  # Show first 5 for debugging
                        })
                    }
            except Exception as search_error:
                print(f"Error during file search: {str(search_error)}")
                return {
                    'statusCode': 404,
                    'headers': cors_headers(),
                    'body': json.dumps({'error': 'File not found'})
                }
        else:
            item = response['Item']
        
        # Use the original path from metadata
        original_path = item.get('s3_paths', {}).get('original', '')
        if not original_path:
            # Fallback to legacy s3_key field
            original_path = item.get('s3_key', '')
        
        if not original_path:
            print(f"No S3 path found for file {file_id}")
            print(f"Item s3_paths: {item.get('s3_paths', {})}")
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({
                    'error': 'File path not found',
                    'file_id': file_id,
                    'available_paths': list(item.get('s3_paths', {}).keys())
                })
            }
        
        print(f"Generating presigned URL for: {original_path}")
        
        download_url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': 'gildarck-media-dev', 'Key': original_path},
            ExpiresIn=3600
        )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'file': item,
                'download_url': download_url,
                'file_id': item.get('file_id'),  # Return the actual file_id from DB
                'original_path': original_path
            }, default=str)
        }
    except Exception as e:
        print(f"Error getting file details for {file_id}: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': f'Failed to get file details: {str(e)}'})
        }

def list_trash_items(user_id):
    """List all items in trash for user - Google Photos style"""
    try:
        # Query all user items and filter trashed ones
        response = table.query(
            KeyConditionExpression=Key('user_id').eq(user_id)
        )
        
        items = response.get('Items', [])
        trash_items = []
        
        for item in items:
            if item.get('processing_status') == 'trashed':
                # Generate thumbnail URL if available
                thumbnail_url = None
                thumbnails = item.get('thumbnails', {})
                if thumbnails.get('medium'):
                    try:
                        thumbnail_url = s3.generate_presigned_url(
                            'get_object',
                            Params={'Bucket': 'gildarck-media-dev', 'Key': thumbnails['medium']},
                            ExpiresIn=3600
                        )
                    except:
                        pass
                
                trash_item = {
                    'file_id': item.get('file_id'),
                    'original_filename': item.get('original_filename'),
                    'trash_date': item.get('trash_date', ''),
                    'file_size': item.get('file_size'),
                    'content_type': item.get('content_type'),
                    'thumbnail_url': thumbnail_url,
                    'media_type': item.get('media_type', 'unknown')
                }
                trash_items.append(trash_item)
        
        # Sort by trash date (newest first)
        trash_items.sort(key=lambda x: x.get('trash_date', ''), reverse=True)
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'items': trash_items,
                'count': len(trash_items),
                'total_size_bytes': sum(item.get('file_size', 0) for item in items if item.get('processing_status') == 'trashed')
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Error listing trash items for user {user_id}: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': f'Failed to list trash: {str(e)}'})
        }
