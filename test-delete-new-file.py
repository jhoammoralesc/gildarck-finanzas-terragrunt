#!/usr/bin/env python3
import boto3
import json

def test_delete_new_file():
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # New file from DynamoDB
    test_file_id = "7d106ba5-bfb0-4003-814f-a54d51ca1068_Screenshot_2022-03-24-15-25-26-069_com"
    
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
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")

if __name__ == "__main__":
    test_delete_new_file()
