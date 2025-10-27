#!/usr/bin/env python3
"""
Test script for media-delete Lambda function
"""
import boto3
import json
import sys

def test_media_delete():
    # Initialize Lambda client
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # Test event - simulating API Gateway request
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
            "action": "list_trash"
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
            print("\n✅ Lambda function executed successfully!")
        else:
            print(f"\n❌ Lambda function failed with status: {response['StatusCode']}")
            
    except Exception as e:
        print(f"❌ Error invoking Lambda: {str(e)}")

if __name__ == "__main__":
    print("Testing media-delete Lambda function...")
    test_media_delete()
