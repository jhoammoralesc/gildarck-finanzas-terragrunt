#!/bin/bash

# Bulk upload all Cancún 2022 media to test complete backend system
export AWS_PROFILE=my-student-user

# Variables
BUCKET_NAME="gildarck-media-dev"
TEST_USER_ID="test-user-cancun-2022"
SOURCE_DIR="/Users/jhoam.morales/Documents/gildarck/images/Takeout/Google Photos/Cancún 2022"
COUNTER=0
SUCCESS=0
FAILED=0

echo "🚀 Starting bulk upload of Cancún 2022 media..."
echo "Source: $SOURCE_DIR"
echo "Bucket: $BUCKET_NAME"
echo "User ID: $TEST_USER_ID"
echo ""

# Find all media files (images and videos)
find "$SOURCE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.mp4" -o -name "*.mov" \) | while read -r file; do
    COUNTER=$((COUNTER + 1))
    
    # Extract filename
    FILENAME=$(basename "$file")
    
    # Create S3 key with organized structure
    S3_KEY="${TEST_USER_ID}/originals/2022/03/${FILENAME}"
    
    echo "[$COUNTER] Uploading: $FILENAME"
    
    # Upload to S3 - this triggers the complete EventBridge flow
    if aws s3 cp "$file" "s3://${BUCKET_NAME}/${S3_KEY}" \
        --region us-east-1 \
        --profile my-student-user \
        --quiet; then
        SUCCESS=$((SUCCESS + 1))
        echo "  ✅ Success"
    else
        FAILED=$((FAILED + 1))
        echo "  ❌ Failed"
    fi
    
    # Small delay to avoid overwhelming the system
    sleep 0.5
    
    # Progress every 10 files
    if [ $((COUNTER % 10)) -eq 0 ]; then
        echo ""
        echo "📊 Progress: $COUNTER files processed | ✅ $SUCCESS success | ❌ $FAILED failed"
        echo ""
    fi
done

echo ""
echo "🎉 Bulk upload completed!"
echo "📊 Final stats:"
echo "  - Total processed: $COUNTER"
echo "  - Successful: $SUCCESS" 
echo "  - Failed: $FAILED"
echo ""
echo "🔄 EventBridge processing should now be running..."
echo "📊 Monitor with:"
echo "  aws logs tail /aws/lambda/gildarck-media-processor --follow --profile my-student-user"
echo "  aws logs tail /aws/lambda/gildarck-thumbnail-generator --follow --profile my-student-user"
