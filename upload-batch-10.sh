#!/bin/bash

# Upload first 10 files to test system before full bulk upload
export AWS_PROFILE=my-student-user

BUCKET_NAME="gildarck-media-dev"
TEST_USER_ID="test-user-cancun-batch"
SOURCE_DIR="/Users/jhoam.morales/Documents/gildarck/images/Takeout/Google Photos/Cancún 2022"

echo "🧪 Testing with first 10 media files..."

find "$SOURCE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.mp4" \) | head -10 | while read -r file; do
    FILENAME=$(basename "$file")
    S3_KEY="${TEST_USER_ID}/originals/2022/03/${FILENAME}"
    
    echo "📤 Uploading: $FILENAME"
    
    aws s3 cp "$file" "s3://${BUCKET_NAME}/${S3_KEY}" \
        --region us-east-1 \
        --profile my-student-user
    
    echo "⏳ Waiting 2s for processing..."
    sleep 2
done

echo ""
echo "✅ Batch test completed!"
echo "🔍 Check results:"
echo "  aws s3 ls s3://${BUCKET_NAME}/${TEST_USER_ID}/ --recursive --profile my-student-user"
