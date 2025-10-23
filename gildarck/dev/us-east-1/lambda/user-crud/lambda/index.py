import json
import boto3
import os
from botocore.exceptions import ClientError

# Initialize Cognito client
cognito_client = boto3.client('cognito-idp', region_name=os.environ['REGION'])

USER_POOL_ID = os.environ['USER_POOL_ID']
CLIENT_ID = os.environ['CLIENT_ID']
CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*')

def cors_headers():
    return {
        'Access-Control-Allow-Origin': CORS_ORIGINS,
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept-Language',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }

def lambda_handler(event, context):
    try:
        http_method = event['httpMethod']
        path = event['path']
        
        if http_method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers(),
                'body': json.dumps({'message': 'CORS preflight'})
            }
        
        # Route requests based on path and method
        if path == '/platform/v1/users' and http_method == 'GET':
            return list_users(event)
        elif path == '/platform/v1/users' and http_method == 'POST':
            return create_user(event)
        elif path.startswith('/platform/v1/users/') and http_method == 'GET':
            user_id = path.split('/')[-1]
            return get_user(user_id)
        elif path.startswith('/platform/v1/users/') and http_method == 'PUT':
            user_id = path.split('/')[-1]
            return update_user(user_id, event)
        elif path.startswith('/platform/v1/users/') and http_method == 'DELETE':
            user_id = path.split('/')[-1]
            return delete_user(user_id)
        else:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': str(e)})
        }

def create_user(event):
    try:
        body = json.loads(event['body'])
        username = body['username']
        email = body['email']
        password = body.get('password', 'TempPassword123!')
        
        response = cognito_client.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=username,
            UserAttributes=[
                {'Name': 'email', 'Value': email},
                {'Name': 'email_verified', 'Value': 'true'}
            ],
            TemporaryPassword=password,
            MessageAction='SUPPRESS'
        )
        
        # Set permanent password
        cognito_client.admin_set_user_password(
            UserPoolId=USER_POOL_ID,
            Username=username,
            Password=password,
            Permanent=True
        )
        
        return {
            'statusCode': 201,
            'headers': cors_headers(),
            'body': json.dumps({
                'message': 'User created successfully',
                'user': {
                    'username': username,
                    'email': email,
                    'status': response['User']['UserStatus']
                }
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def get_user(user_id):
    try:
        response = cognito_client.admin_get_user(
            UserPoolId=USER_POOL_ID,
            Username=user_id
        )
        
        user_attributes = {}
        for attr in response['UserAttributes']:
            user_attributes[attr['Name']] = attr['Value']
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'username': response['Username'],
                'status': response['UserStatus'],
                'attributes': user_attributes,
                'created': response['UserCreateDate'].isoformat(),
                'modified': response['UserLastModifiedDate'].isoformat()
            })
        }
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'User not found'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def update_user(user_id, event):
    try:
        body = json.loads(event['body'])
        
        user_attributes = []
        if 'email' in body:
            user_attributes.append({'Name': 'email', 'Value': body['email']})
        
        if user_attributes:
            cognito_client.admin_update_user_attributes(
                UserPoolId=USER_POOL_ID,
                Username=user_id,
                UserAttributes=user_attributes
            )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'User updated successfully'})
        }
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'User not found'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def delete_user(user_id):
    try:
        cognito_client.admin_delete_user(
            UserPoolId=USER_POOL_ID,
            Username=user_id
        )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'User deleted successfully'})
        }
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'User not found'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def list_users(event):
    try:
        query_params = event.get('queryStringParameters') or {}
        limit = int(query_params.get('limit', 10))
        
        response = cognito_client.list_users(
            UserPoolId=USER_POOL_ID,
            Limit=limit
        )
        
        users = []
        for user in response['Users']:
            user_attributes = {}
            for attr in user['Attributes']:
                user_attributes[attr['Name']] = attr['Value']
            
            users.append({
                'username': user['Username'],
                'status': user['UserStatus'],
                'attributes': user_attributes,
                'created': user['UserCreateDate'].isoformat(),
                'modified': user['UserLastModifiedDate'].isoformat()
            })
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'users': users,
                'count': len(users)
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }
