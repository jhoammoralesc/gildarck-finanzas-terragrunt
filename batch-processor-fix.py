#!/usr/bin/env python3

# 🔧 BATCH PROCESSOR FIX - Handle both string and object file formats

def generate_batch_upload_urls(files: List[Dict], user_id: str, strategy: Dict) -> List[Dict]:
    """Generate presigned URLs for batch of files"""
    upload_urls = []
    
    try:
        for i, file_info in enumerate(files):
            # 🔧 FIX: Handle both string and object formats
            if isinstance(file_info, str):
                # If it's a string, it might be a filename only
                filename = file_info
                content_type = 'application/octet-stream'
            elif isinstance(file_info, dict):
                # If it's a dict, extract filename and contentType
                filename = file_info.get('filename', f'file_{i}')
                content_type = file_info.get('contentType', 'application/octet-stream')
            else:
                # Skip invalid entries
                logger.warning(f"Skipping invalid file_info at index {i}: {type(file_info)}")
                continue
            
            # Generate S3 key with date organization
            s3_key = generate_s3_key(user_id, filename)
            
            # Generate presigned URL
            presigned_url = s3_client.generate_presigned_url(
                'put_object',
                Params={
                    'Bucket': BUCKET_NAME,
                    'Key': s3_key,
                    'ContentType': content_type
                },
                ExpiresIn=3600  # 1 hour
            )
            
            upload_urls.append({
                'filename': filename,
                'upload_url': presigned_url,
                'upload_type': 'simple',
                's3_key': s3_key,
                'content_type': content_type
            })
            
            logger.info(f"Generated upload URL for {filename}")
        
        return upload_urls
        
    except Exception as e:
        logger.error(f"Error generating upload URLs: {str(e)}")
        raise

print("🔧 Apply this fix to the batch processor to handle both formats!")
