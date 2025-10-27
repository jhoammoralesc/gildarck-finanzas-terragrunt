#!/usr/bin/env python3
import boto3

def clean_all_dynamodb():
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('gildarck-media-metadata-dev')
    
    # Scan all items
    response = table.scan()
    items = response['Items']
    
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response['Items'])
    
    print(f"Found {len(items)} items to delete")
    
    if items:
        for item in items:
            table.delete_item(
                Key={
                    'user_id': item['user_id'],
                    'file_id': item['file_id']
                }
            )
            print(f"🗑️ Deleted {item['file_id']}")
        
        print(f"✅ Deleted all {len(items)} items from DynamoDB")
    else:
        print("✅ DynamoDB is already empty")

if __name__ == "__main__":
    clean_all_dynamodb()
