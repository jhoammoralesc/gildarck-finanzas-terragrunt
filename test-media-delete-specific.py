#!/usr/bin/env python3
"""
Test script for media-delete Lambda function with specific file
"""
import boto3
import json
import sys

def test_media_delete_specific():
    # Initialize Lambda client
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # Test file ID from DynamoDB scan - using one that actually exists
    test_file_id = "91d6d94b-363c-4312-83b5-5f43c4dbc9a3_Screenshot_2022-03-25-12-34-48-673_com"
    
    # Test event - simulating API Gateway request for trash action
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
        # Invoke the Lambda function
        response = lambda_client.invoke(
            FunctionName='gildarck-media-delete',
            InvocationType='RequestResponse',
            Payload=json.dumps(test_event)
        )
        
        # Parse response
        payload = json.loads(response['Payload'].read())
        
        print("Lambda Response:")
        print(json.dumps(payload, indent=2))
        
        if response['StatusCode'] == 200:
            print(f"\n✅ Lambda function executed successfully!")
            
            # Parse the body to check results
            if 'body' in payload:
                body = json.loads(payload['body'])
                if body.get('success'):
                    print(f"✅ Delete operation successful!")
                    if 'results' in body:
                        for result in body['results']:
                            if result.get('success'):
                                print(f"✅ File {result['file_id']} moved to trash successfully")
                            else:
                                print(f"❌ File {result['file_id']} failed: {result.get('error', 'Unknown error')}")
                else:
                    print(f"❌ Delete operation failed: {body.get('error', 'Unknown error')}")
        else:
            print(f"\n❌ Lambda function failed with status: {response['StatusCode']}")
            
    except Exception as e:
        print(f"❌ Error invoking Lambda: {str(e)}")

if __name__ == "__main__":
    print("Testing media-delete Lambda function with specific file...")
    test_media_delete_specific()
