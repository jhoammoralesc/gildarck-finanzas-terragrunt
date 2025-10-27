#!/usr/bin/env python3
"""
Test script for media-delete with real file from S3
"""
import boto3
import json

def test_delete_real_file():
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # File from DynamoDB that actually exists
    test_file_id = "591c1f1f-f5be-4561-b482-d8db798f83db_Screenshot_2022-03-24-15-25-26-069_com"
    
    test_event = {
        "httpMethod": "POST",
        "requestContext": {
            "authorizer": {
                "claims": {
                    "sub": "34581438-20d1-70f7-6422-33faef85360d"
                }
            }
        },
        "body": json.dumps({
            "action": "trash",
            "file_ids": [test_file_id]
        })
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName='gildarck-media-delete',
            InvocationType='RequestResponse',
            Payload=json.dumps(test_event)
        )
        
        payload = json.loads(response['Payload'].read())
        print("Lambda Response:")
        print(json.dumps(payload, indent=2))
        
        if 'body' in payload:
            body = json.loads(payload['body'])
            if body.get('success'):
                for result in body['results']:
                    if result.get('success'):
                        print(f"✅ File {result['file_id']} moved to trash")
                    else:
                        print(f"❌ File {result['file_id']} failed: {result.get('error')}")
            else:
                print(f"❌ Operation failed: {body.get('error')}")
                
    except Exception as e:
        print(f"❌ Error: {str(e)}")

if __name__ == "__main__":
    print("Testing deletion with real file from S3...")
    test_delete_real_file()
