import json
import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
table = dynamodb.Table('gildarck-media-metadata-dev')

def lambda_handler(event, context):
    try:
        # Extract user_id (Cognito sub) consistently with other functions
        user_id = event.get('requestContext', {}).get('authorizer', {}).get('sub')
        if not user_id:
            return {
                'statusCode': 401,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'Unauthorized - Missing user ID'})
            }
        
        path = event['pathParameters']['proxy'] if event.get('pathParameters') else ''
        method = event['httpMethod']
        
        print(f"Processing: {method} {path} for user {user_id}")
        
        if method == 'GET':
            if path == 'list':
                return list_media(user_id, event.get('queryStringParameters', {}))
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

def list_media(user_id, params):
    try:
        limit = int(params.get('limit', 50))
        last_key = params.get('lastKey')
        
        query_params = {
            'KeyConditionExpression': Key('user_id').eq(user_id),
            'Limit': limit,
            'ScanIndexForward': False
        }
        
        if last_key:
            query_params['ExclusiveStartKey'] = json.loads(last_key)
        
        response = table.query(**query_params)
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'items': response['Items'],
                'lastKey': json.dumps(response.get('LastEvaluatedKey')) if response.get('LastEvaluatedKey') else None,
                'count': len(response['Items'])
            }, default=str)
        }
    except Exception as e:
        print(f"Error listing media for user {user_id}: {str(e)}")
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
        response = table.get_item(Key={'user_id': user_id, 'file_id': file_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'File not found'})
            }
        
        item = response['Item']
        
        # Use the original path from metadata
        original_path = item.get('s3_paths', {}).get('original', '')
        if not original_path:
            # Fallback to legacy s3_key field
            original_path = item.get('s3_key', '')
        
        if not original_path:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'File path not found'})
            }
        
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
                'file_id': file_id
            }, default=str)
        }
    except Exception as e:
        print(f"Error getting file details for {file_id}: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': f'Failed to get file details: {str(e)}'})
        }
