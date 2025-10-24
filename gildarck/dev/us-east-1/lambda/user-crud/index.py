import json
import boto3
import os
import hmac
import hashlib
import base64
from botocore.exceptions import ClientError

# Initialize Cognito client
cognito_client = boto3.client('cognito-idp', region_name=os.environ['REGION'])

USER_POOL_ID = os.environ['USER_POOL_ID']
CLIENT_ID = os.environ['CLIENT_ID']
CLIENT_SECRET = os.environ.get('CLIENT_SECRET')
CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*')

def get_secret_hash(username):
    if not CLIENT_SECRET:
        return None
    message = username + CLIENT_ID
    dig = hmac.new(CLIENT_SECRET.encode('UTF-8'), message.encode('UTF-8'), hashlib.sha256).digest()
    return base64.b64encode(dig).decode()

def get_cors_origin(event):
    origin = event.get('headers', {}).get('origin') or event.get('headers', {}).get('Origin')
    allowed_origins = [
        'https://dev.gildarck.com',
        'https://develop.d1voxl70yl4svu.amplifyapp.com',
        'http://localhost:3000'
    ]
    return origin if origin in allowed_origins else allowed_origins[0]

def cors_headers(event=None):
    origin = get_cors_origin(event) if event else CORS_ORIGINS
    return {
        'Access-Control-Allow-Origin': origin,
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
                'headers': cors_headers(event),
                'body': json.dumps({'message': 'CORS preflight'})
            }
        
        # Route requests based on path and method
        # Auth endpoints
        if path == '/auth/login' and http_method == 'POST':
            return login_user(event)
        elif path == '/auth/register' and http_method == 'POST':
            return register_user(event)
        elif path == '/auth/change-password' and http_method == 'POST':
            return change_password(event)
        elif path == '/auth/set-new-password' and http_method == 'POST':
            return set_new_password(event)
        elif path == '/auth/logout' and http_method == 'POST':
            return logout_user(event)
        # Legacy auth endpoints (redirect to new functions)
        elif path == '/platform/v1/account/login' and http_method == 'POST':
            return login_user(event)
        elif path == '/platform/v1/account/register' and http_method == 'POST':
            return register_user(event)
        # User CRUD endpoints
        elif path == '/platform/v1/users' and http_method == 'GET':
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
                'headers': cors_headers(event),
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': cors_headers(event),
            'body': json.dumps({'error': str(e)})
        }

def login_user(event):
    try:
        body = json.loads(event['body'])
        email = body['email']
        password = body['password']
        
        auth_params = {
            'USERNAME': email,
            'PASSWORD': password
        }
        
        secret_hash = get_secret_hash(email)
        if secret_hash:
            auth_params['SECRET_HASH'] = secret_hash
        
        response = cognito_client.initiate_auth(
            ClientId=CLIENT_ID,
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters=auth_params
        )
        
        # Check if password change is required
        if 'ChallengeName' in response and response['ChallengeName'] == 'NEW_PASSWORD_REQUIRED':
            return {
                'statusCode': 200,
                'headers': cors_headers(event),
                'body': json.dumps({
                    'success': True,
                    'challenge': 'NEW_PASSWORD_REQUIRED',
                    'session': response['Session'],
                    'message': 'Password change required for first login'
                })
            }
        
        # Get user info for successful login
        user_info = cognito_client.get_user(AccessToken=response['AuthenticationResult']['AccessToken'])
        
        user_attributes = {}
        for attr in user_info['UserAttributes']:
            user_attributes[attr['Name']] = attr['Value']
        
        return {
            'statusCode': 200,
            'headers': cors_headers(event),
            'body': json.dumps({
                'success': True,
                'message': 'Login successful',
                'data': {
                    'access_token': response['AuthenticationResult']['AccessToken'],
                    'id_token': response['AuthenticationResult']['IdToken'],
                    'refresh_token': response['AuthenticationResult']['RefreshToken'],
                    'expires_in': response['AuthenticationResult']['ExpiresIn'],
                    'user': {
                        'id': user_attributes.get('sub'),
                        'email': user_attributes.get('email'),
                        'name': user_attributes.get('name', '')
                    }
                }
            })
        }
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'NotAuthorizedException':
            return {
                'statusCode': 401,
                'headers': cors_headers(event),
                'body': json.dumps({'error': 'Invalid email or password'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def register_user(event):
    try:
        body = json.loads(event['body'])
        email = body['email']
        name = body.get('name', '')
        
        # Generate a unique username since email alias is configured
        import uuid
        username = str(uuid.uuid4())
        
        # Use admin_create_user to create user with temporary password
        response = cognito_client.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=username,
            UserAttributes=[
                {'Name': 'email', 'Value': email},
                {'Name': 'email_verified', 'Value': 'true'},
                {'Name': 'name', 'Value': name}
            ]
        )
        
        return {
            'statusCode': 201,
            'headers': cors_headers(event),
            'body': json.dumps({
                'message': 'User registered successfully. Check your email for temporary password.',
                'user_sub': response['User']['Username'],
                'status': response['User']['UserStatus']
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def change_password(event):
    try:
        body = json.loads(event['body'])
        access_token = body['access_token']
        old_password = body['old_password']
        new_password = body['new_password']
        
        cognito_client.change_password(
            AccessToken=access_token,
            PreviousPassword=old_password,
            ProposedPassword=new_password
        )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(event),
            'body': json.dumps({'message': 'Password changed successfully'})
        }
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'NotAuthorizedException':
            return {
                'statusCode': 401,
                'headers': cors_headers(event),
                'body': json.dumps({'error': 'Invalid current password or token'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def set_new_password(event):
    try:
        body = json.loads(event['body'])
        session = body['session']
        username = body['username']
        new_password = body['new_password']
        
        challenge_responses = {
            'USERNAME': username,
            'NEW_PASSWORD': new_password
        }
        
        secret_hash = get_secret_hash(username)
        if secret_hash:
            challenge_responses['SECRET_HASH'] = secret_hash
        
        response = cognito_client.respond_to_auth_challenge(
            ClientId=CLIENT_ID,
            ChallengeName='NEW_PASSWORD_REQUIRED',
            Session=session,
            ChallengeResponses=challenge_responses
        )
        
        # Get user info for successful password set
        user_info = cognito_client.get_user(AccessToken=response['AuthenticationResult']['AccessToken'])
        
        user_attributes = {}
        for attr in user_info['UserAttributes']:
            user_attributes[attr['Name']] = attr['Value']
        
        return {
            'statusCode': 200,
            'headers': cors_headers(event),
            'body': json.dumps({
                'success': True,
                'message': 'Password set successfully',
                'data': {
                    'access_token': response['AuthenticationResult']['AccessToken'],
                    'id_token': response['AuthenticationResult']['IdToken'],
                    'refresh_token': response['AuthenticationResult']['RefreshToken'],
                    'expires_in': response['AuthenticationResult']['ExpiresIn'],
                    'user': {
                        'id': user_attributes.get('sub'),
                        'email': user_attributes.get('email'),
                        'name': user_attributes.get('name', '')
                    }
                }
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def logout_user(event):
    try:
        body = json.loads(event['body'])
        access_token = body.get('access_token')
        
        if access_token:
            # Invalidate the access token
            cognito_client.global_sign_out(
                AccessToken=access_token
            )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(event),
            'body': json.dumps({
                'success': True,
                'message': 'Logout successful'
            })
        }
        
    except ClientError as e:
        # Even if token is invalid, we consider logout successful
        return {
            'statusCode': 200,
            'headers': cors_headers(event),
            'body': json.dumps({
                'success': True,
                'message': 'Logout successful'
            })
        }

def create_user(event):
    try:
        body = json.loads(event['body'])
        email = body['email']
        password = body.get('password', 'TempPassword123!')
        name = body.get('name', '')
        
        response = cognito_client.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=email,
            UserAttributes=[
                {'Name': 'email', 'Value': email},
                {'Name': 'email_verified', 'Value': 'true'},
                {'Name': 'name', 'Value': name}
            ],
            TemporaryPassword=password,
            MessageAction='SUPPRESS'
        )
        
        # Set permanent password
        cognito_client.admin_set_user_password(
            UserPoolId=USER_POOL_ID,
            Username=email,
            Password=password,
            Permanent=True
        )
        
        return {
            'statusCode': 201,
            'headers': cors_headers(event),
            'body': json.dumps({
                'message': 'User created successfully',
                'user': {
                    'email': email,
                    'name': name,
                    'status': response['User']['UserStatus']
                }
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
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
            'headers': cors_headers(event),
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
                'headers': cors_headers(event),
                'body': json.dumps({'error': 'User not found'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }

def update_user(user_id, event):
    try:
        body = json.loads(event['body'])
        
        user_attributes = []
        if 'email' in body:
            user_attributes.append({'Name': 'email', 'Value': body['email']})
        if 'name' in body:
            user_attributes.append({'Name': 'name', 'Value': body['name']})
        
        if user_attributes:
            cognito_client.admin_update_user_attributes(
                UserPoolId=USER_POOL_ID,
                Username=user_id,
                UserAttributes=user_attributes
            )
        
        return {
            'statusCode': 200,
            'headers': cors_headers(event),
            'body': json.dumps({'message': 'User updated successfully'})
        }
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            return {
                'statusCode': 404,
                'headers': cors_headers(event),
                'body': json.dumps({'error': 'User not found'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
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
            'headers': cors_headers(event),
            'body': json.dumps({'message': 'User deleted successfully'})
        }
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            return {
                'statusCode': 404,
                'headers': cors_headers(event),
                'body': json.dumps({'error': 'User not found'})
            }
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
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
            'headers': cors_headers(event),
            'body': json.dumps({
                'users': users,
                'count': len(users)
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 400,
            'headers': cors_headers(event),
            'body': json.dumps({'error': e.response['Error']['Message']})
        }
