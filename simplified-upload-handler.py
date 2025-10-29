import json
import boto3
import uuid
import os
from datetime import datetime

s3 = boto3.client('s3')
sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['S3_BUCKET']
BATCH_QUEUE_URL = os.environ['UPLOAD_BATCH_QUEUE_URL']
BATCH_TABLE = os.environ.get('BATCH_TABLE', 'gildarck-batch-uploads-dev')

def get_cors_headers(event):
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
        'Content-Type': 'application/json'
    }

def extract_cognito_sub(event):
    return event['requestContext']['authorizer']['claims']['sub']

def batch_upload_initiate(event, user_id):
    """Send ALL uploads to SQS for batch processing"""
    try:
        body = json.loads(event['body'])
        files = body.get('files', [])
        
        if not files:
            return error_response(400, 'No files provided', event)
        
        master_batch_id = str(uuid.uuid4())
        
        # Send to SQS regardless of file count or size
        message = {
            'master_batch_id': master_batch_id,
            'user_id': user_id,
            'files': files,
            'timestamp': datetime.now().isoformat()
        }
        
        sqs.send_message(
            QueueUrl=BATCH_QUEUE_URL,
            MessageBody=json.dumps(message)
        )
        
        return success_response({
            'masterBatchId': master_batch_id,
            'status': 'processing',
            'fileCount': len(files)
        }, event)
        
    except Exception as e:
        return error_response(500, f'Batch initiate failed: {str(e)}', event)

def get_batch_status(event, user_id):
    """Get batch status from DynamoDB"""
    try:
        master_batch_id = event['queryStringParameters'].get('masterBatchId')
        
        if not master_batch_id:
            return error_response(400, 'masterBatchId required', event)
        
        batch_table = dynamodb.Table(BATCH_TABLE)
        
        response = batch_table.get_item(
            Key={'batch_id': master_batch_id}
        )
        
        if 'Item' not in response:
            return success_response({
                'status': 'processing',
                'progress': 0
            }, event)
        
        item = response['Item']
        
        if item.get('user_id') != user_id:
            return error_response(403, 'Access denied', event)
        
        return success_response({
            'status': item.get('status', 'processing'),
            'upload_urls': item.get('upload_urls', []),
            'processed_files': item.get('processed_files', 0),
            'total_files': item.get('total_files', 0)
        }, event)
        
    except Exception as e:
        return error_response(500, f'Batch status failed: {str(e)}', event)

def lambda_handler(event, context):
    try:
        http_method = event['httpMethod']
        path = event['path']
        
        if http_method == 'OPTIONS':
            return {'statusCode': 200, 'headers': get_cors_headers(event), 'body': ''}
        
        user_id = extract_cognito_sub(event)
        
        if http_method == 'POST' and path.endswith('/upload/batch-initiate'):
            return batch_upload_initiate(event, user_id)
        elif http_method == 'GET' and '/upload/batch-status' in path:
            return get_batch_status(event, user_id)
        else:
            return error_response(404, f'Endpoint not found: {http_method} {path}', event)
            
    except Exception as e:
        return error_response(500, f'Internal server error: {str(e)}', event)

def error_response(status_code, message, event=None):
    return {
        'statusCode': status_code,
        'headers': get_cors_headers(event) if event else {},
        'body': json.dumps({'error': message})
    }

def success_response(data, event=None):
    return {
        'statusCode': 200,
        'headers': get_cors_headers(event) if event else {},
        'body': json.dumps(data)
    }
