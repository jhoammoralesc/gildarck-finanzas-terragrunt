#!/usr/bin/env python3
"""
Script to sync DynamoDB with S3 - remove DynamoDB entries for files that don't exist in S3
"""
import boto3
import json

def sync_dynamodb_with_s3():
    # Initialize clients
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    s3_client = boto3.client('s3', region_name='us-east-1')
    
    table = dynamodb.Table('gildarck-media-metadata-dev')
    bucket_name = 'gildarck-media-dev'
    
    # Scan all items in DynamoDB
    response = table.scan()
    items = response['Items']
    
    # Continue scanning if there are more items
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response['Items'])
    
    print(f"Found {len(items)} items in DynamoDB")
    
    items_to_delete = []
    
    for item in items:
        user_id = item['user_id']
        file_id = item['file_id']
        
        # Get the S3 path from the item
        s3_paths = item.get('s3_paths', {})
        original_path = s3_paths.get('original', '')
        
        if not original_path:
            # Try legacy s3_key field
            original_path = item.get('s3_key', '')
        
        if not original_path:
            print(f"⚠️  No S3 path found for {file_id}, will delete from DynamoDB")
            items_to_delete.append(item)
            continue
        
        # Check if file exists in S3
        try:
            s3_client.head_object(Bucket=bucket_name, Key=original_path)
            print(f"✅ {file_id}: File exists in S3")
        except s3_client.exceptions.NoSuchKey:
            print(f"❌ {file_id}: File missing in S3 at {original_path}")
            items_to_delete.append(item)
        except Exception as e:
            print(f"⚠️  {file_id}: Error checking S3: {str(e)}")
            items_to_delete.append(item)
    
    print(f"\nFound {len(items_to_delete)} items to delete from DynamoDB")
    
    if items_to_delete:
        confirm = input(f"Delete {len(items_to_delete)} items from DynamoDB? (y/N): ")
        if confirm.lower() == 'y':
            deleted_count = 0
            for item in items_to_delete:
                try:
                    table.delete_item(
                        Key={
                            'user_id': item['user_id'],
                            'file_id': item['file_id']
                        }
                    )
                    print(f"🗑️  Deleted {item['file_id']} from DynamoDB")
                    deleted_count += 1
                except Exception as e:
                    print(f"❌ Error deleting {item['file_id']}: {str(e)}")
            
            print(f"\n✅ Successfully deleted {deleted_count} items from DynamoDB")
        else:
            print("❌ Deletion cancelled")
    else:
        print("✅ No items need to be deleted - DynamoDB and S3 are in sync")

if __name__ == "__main__":
    print("Syncing DynamoDB with S3...")
    sync_dynamodb_with_s3()
