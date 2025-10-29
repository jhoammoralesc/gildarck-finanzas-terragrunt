#!/usr/bin/env python3
"""
Fix batch upload handler by removing duplicate batch_upload_initiate function.
Keep only the SQS version.
"""

import boto3
import zipfile
import io
import os

# Get current Lambda code
lambda_client = boto3.client('lambda', region_name='us-east-1')
response = lambda_client.get_function(FunctionName='gildarck-upload-handler')

# Download and extract
import urllib.request
code_url = response['Code']['Location']
with urllib.request.urlopen(code_url) as response:
    zip_data = response.read()

# Extract index.py
with zipfile.ZipFile(io.BytesIO(zip_data)) as z:
    code = z.read('index.py').decode('utf-8')

# Find and remove duplicate function
lines = code.split('\n')
new_lines = []
skip_until_next_def = False
found_first_batch_init = False

for i, line in enumerate(lines):
    if 'def batch_upload_initiate' in line:
        if not found_first_batch_init:
            found_first_batch_init = True
            new_lines.append(line)
        else:
            # Skip second definition
            skip_until_next_def = True
            print(f"Removing duplicate at line {i}")
            continue
    
    if skip_until_next_def:
        if line.startswith('def ') and 'batch_upload_initiate' not in line:
            skip_until_next_def = False
            new_lines.append(line)
        continue
    
    new_lines.append(line)

fixed_code = '\n'.join(new_lines)

# Create new zip
zip_buffer = io.BytesIO()
with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zipf:
    zipf.writestr('index.py', fixed_code)

# Update Lambda
zip_buffer.seek(0)
lambda_client.update_function_code(
    FunctionName='gildarck-upload-handler',
    ZipFile=zip_buffer.read()
)

print("✅ Lambda updated successfully")
print("Removed duplicate batch_upload_initiate function")
