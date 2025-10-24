include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-dynamodb-table.git?ref=v4.0.1"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.environment_vars.locals.environment
  name = "gildarck-media-metadata-${local.environment}"
}

inputs = {
  name           = local.name
  hash_key       = "user_id"
  range_key      = "file_id"
  billing_mode   = "PAY_PER_REQUEST"
  
  attributes = [
    {
      name = "user_id"
      type = "S"
    },
    {
      name = "file_id"
      type = "S"
    },
    {
      name = "file_hash"
      type = "S"
    },
    {
      name = "created_date"
      type = "S"
    },
    {
      name = "location_lat_lng"
      type = "S"
    }
  ]
  
  global_secondary_indexes = [
    {
      name            = "FileHashIndex"
      hash_key        = "file_hash"
      projection_type = "ALL"
    },
    {
      name            = "DateIndex"
      hash_key        = "user_id"
      range_key       = "created_date"
      projection_type = "ALL"
    },
    {
      name            = "LocationIndex"
      hash_key        = "user_id"
      range_key       = "location_lat_lng"
      projection_type = "ALL"
    }
  ]
  
  tags = {
    Environment = local.environment
    Service     = "dynamodb"
    Name        = local.name
  }
}

# Schema de metadatos (como comentario para referencia):
# {
#   "user_id": "uuid",
#   "file_id": "uuid", 
#   "file_hash": "sha256",
#   "filename": "original_name.jpg",
#   "file_type": "image/jpeg",
#   "file_size": 1024000,
#   "s3_key": "user_id/media/images/file_id.jpg",
#   "created_date": "2025-10-24T09:43:00Z",
#   "modified_date": "2025-10-24T09:43:00Z",
#   "upload_date": "2025-10-24T09:43:00Z",
#   "media_type": "image|video|document",
#   "category": "images|videos|documents|trash",
#   "width": 1920,
#   "height": 1080,
#   "duration": 120, // for videos in seconds
#   "location": {
#     "latitude": 40.7128,
#     "longitude": -74.0060,
#     "address": "New York, NY",
#     "country": "US"
#   },
#   "location_lat_lng": "40.7128,-74.0060", // GSI key
#   "camera_info": {
#     "make": "Apple",
#     "model": "iPhone 15 Pro",
#     "lens": "Main Camera",
#     "focal_length": "24mm",
#     "aperture": "f/1.78",
#     "iso": 100,
#     "shutter_speed": "1/120"
#   },
#   "faces": [
#     {
#       "face_id": "uuid",
#       "person_name": "John Doe",
#       "confidence": 0.95,
#       "bounding_box": {
#         "x": 100, "y": 100, "width": 200, "height": 200
#       }
#     }
#   ],
#   "objects": [
#     {
#       "label": "car",
#       "confidence": 0.89,
#       "bounding_box": {
#         "x": 300, "y": 400, "width": 500, "height": 300
#       }
#     }
#   ],
#   "colors": ["#FF5733", "#33FF57", "#3357FF"],
#   "tags": ["vacation", "family", "beach"],
#   "albums": ["Summer 2025", "Family Photos"],
#   "is_favorite": false,
#   "is_archived": false,
#   "is_deleted": false,
#   "thumbnails": {
#     "small": "s3_key_thumb_150.jpg",
#     "medium": "s3_key_thumb_500.jpg", 
#     "large": "s3_key_thumb_1000.jpg"
#   },
#   "processing_status": "completed|processing|failed",
#   "ai_analysis": {
#     "scene": "outdoor",
#     "activity": "beach volleyball",
#     "mood": "happy",
#     "quality_score": 0.92
#   }
# }
