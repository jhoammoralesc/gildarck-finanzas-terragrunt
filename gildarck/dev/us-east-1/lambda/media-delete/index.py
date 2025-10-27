import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any
from boto3.dynamodb.conditions import Key
from decimal import Decimal

# Custom JSON encoder for Decimal values
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super(DecimalEncoder, self).default(o)

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('gildarck-media-metadata-dev')

BUCKET_NAME = 'gildarck-media-dev'

def extract_cognito_sub(event):
    """Extract cognito sub from API Gateway authorizer context"""
    try:
        if 'requestContext' in event and 'authorizer' in event['requestContext']:
            authorizer = event['requestContext']['authorizer']
            
            if 'claims' in authorizer and 'sub' in authorizer['claims']:
                return authorizer['claims']['sub']
            
            if 'sub' in authorizer:
                return authorizer['sub']
                
            if 'principalId' in authorizer:
                return authorizer['principalId']
        
        raise ValueError("Cognito sub not found in request context")
    except Exception as e:
        logger.error(f"Error extracting Cognito sub: {str(e)}")
        raise ValueError("Cognito sub not found in request context")

def lambda_handler(event, context):
    """
    Google Photos-style delete handler
    Supports: soft delete (move to trash), permanent delete, restore from trash, list trash
    """
    try:
        # Extract user info consistently with other functions
        user_id = extract_cognito_sub(event)
        
        # Handle OPTIONS request for CORS
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers(),
                'body': ''
            }
        
        # Parse request with better error handling
        body_str = event.get('body')
        if not body_str:
            return error_response('Missing request body')
        
        try:
            body = json.loads(body_str)
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in request body: {str(e)}")
            return error_response('Invalid JSON in request body')
        
        action = body.get('action')  # 'trash', 'delete', 'restore', 'list_trash'
        file_ids = body.get('file_ids', [])  # List of file IDs
        
        logger.info(f"Processing {action} for user {user_id}, files: {file_ids}")
        
        results = []
        
        if action == 'trash':
            if not file_ids:
                return error_response('Missing file_ids for trash action')
            results = move_to_trash(user_id, file_ids)
        elif action == 'delete':
            if not file_ids:
                return error_response('Missing file_ids for delete action')
            results = permanent_delete(user_id, file_ids)
        elif action == 'restore':
            if not file_ids:
                return error_response('Missing file_ids for restore action')
            results = restore_from_trash(user_id, file_ids)
        elif action == 'list_trash':
            results = list_trash_items(user_id)
        else:
            return error_response(f'Invalid action: {action}')
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'success': True,
                'action': action,
                'results': results
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        logger.error(f"Error in media delete: {str(e)}")
        return error_response(str(e))

def cors_headers():
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    }

def error_response(error_message):
    return {
        'statusCode': 400,
        'headers': cors_headers(),
        'body': json.dumps({
            'success': False,
            'error': error_message
        }, cls=DecimalEncoder)
    }

def move_to_trash(user_id: str, file_ids: List[str]) -> List[Dict]:
    """Move files to trash (soft delete) - Google Photos style"""
    results = []
    
    for file_id in file_ids:
        try:
            # Get file metadata
            response = table.get_item(
                Key={'user_id': user_id, 'file_id': file_id}
            )
            
            if 'Item' not in response:
                results.append({'file_id': file_id, 'success': False, 'error': 'File not found in database'})
                continue
            
            item = response['Item']
            
            # Check if already in trash
            if item.get('processing_status') == 'trashed':
                results.append({'file_id': file_id, 'success': False, 'error': 'File already in trash'})
                continue
            
            # Get original path from s3_paths structure (consistent with media-processor)
            s3_paths = item.get('s3_paths', {})
            original_path = s3_paths.get('original', '')
            
            if not original_path:
                # Fallback to legacy s3_key field
                original_path = item.get('s3_key', '')
            
            if not original_path:
                # Try to construct path from file_id and filename
                filename = item.get('filename', file_id)
                original_path = f"{user_id}/originals/{filename}"
                logger.info(f"Constructed path for {file_id}: {original_path}")
            
            logger.info(f"Attempting to move {file_id} from path: {original_path}")
            
            # Find the actual file in S3 with multiple fallback strategies
            actual_path = find_actual_s3_path(user_id, file_id, original_path, item)
            
            if not actual_path:
                results.append({'file_id': file_id, 'success': False, 'error': 'File not found in S3'})
                continue
            
            # Create trash path maintaining date structure
            if '/originals/' in actual_path:
                trash_path = actual_path.replace('/originals/', '/trash/')
            else:
                # Fallback for files not in originals folder
                trash_path = f"{user_id}/trash/{file_id}"
            
            logger.info(f"Moving {actual_path} to {trash_path}")
            
            # Copy to trash
            s3_client.copy_object(
                Bucket=BUCKET_NAME,
                CopySource={'Bucket': BUCKET_NAME, 'Key': actual_path},
                Key=trash_path,
                Metadata={
                    'trashed-date': datetime.utcnow().isoformat(),
                    'original-path': actual_path
                },
                MetadataDirective='REPLACE'
            )
            
            # Delete from originals
            s3_client.delete_object(Bucket=BUCKET_NAME, Key=actual_path)
            
            # Move thumbnails to trash (handle missing thumbnails gracefully)
            thumbnails = item.get('thumbnails', {})
            trash_thumbnails = {}
            
            for size in ['small', 'medium', 'large']:
                thumb_path = thumbnails.get(size, f"{user_id}/thumbnails/{size}/{file_id}_{size[0]}.webp")
                trash_thumb_path = f"{user_id}/trash/thumbnails/{size}/{file_id}_{size[0]}.webp"
                
                try:
                    # Check if thumbnail exists before trying to move it
                    s3_client.head_object(Bucket=BUCKET_NAME, Key=thumb_path)
                    s3_client.copy_object(
                        Bucket=BUCKET_NAME,
                        CopySource={'Bucket': BUCKET_NAME, 'Key': thumb_path},
                        Key=trash_thumb_path
                    )
                    s3_client.delete_object(Bucket=BUCKET_NAME, Key=thumb_path)
                    trash_thumbnails[size] = trash_thumb_path
                    logger.info(f"Moved thumbnail {thumb_path} to trash")
                except Exception as thumb_error:
                    logger.warning(f"Thumbnail {thumb_path} not found or could not be moved: {str(thumb_error)}")
                    # Create placeholder path for consistency
                    trash_thumbnails[size] = trash_thumb_path
            
            # Update metadata - mark as trashed with consistent structure
            updated_s3_paths = s3_paths.copy() if s3_paths else {}
            updated_s3_paths['original'] = trash_path
            
            table.update_item(
                Key={'user_id': user_id, 'file_id': file_id},
                UpdateExpression='SET #status = :status, trash_date = :trash_date, s3_paths = :s3_paths, thumbnails = :thumbnails',
                ExpressionAttributeNames={'#status': 'processing_status'},
                ExpressionAttributeValues={
                    ':status': 'trashed',
                    ':trash_date': datetime.utcnow().isoformat(),
                    ':s3_paths': updated_s3_paths,
                    ':thumbnails': trash_thumbnails
                }
            )
            
            results.append({'file_id': file_id, 'success': True, 'action': 'moved_to_trash'})
            logger.info(f"Successfully moved {file_id} to trash")
            
        except Exception as e:
            logger.error(f"Error moving {file_id} to trash: {str(e)}")
            results.append({'file_id': file_id, 'success': False, 'error': str(e)})
    
    return results

def find_actual_s3_path(user_id: str, file_id: str, original_path: str, item: Dict) -> str:
    """Find the actual S3 path for a file using multiple strategies"""
    
    # Strategy 1: Try the original path as-is
    try:
        s3_client.head_object(Bucket=BUCKET_NAME, Key=original_path)
        logger.info(f"Found file at original path: {original_path}")
        return original_path
    except:
        pass
    
    # Strategy 2: Try case variations of the extension
    if original_path.lower().endswith('.jpg'):
        alt_path = original_path[:-4] + '.JPG'
        try:
            s3_client.head_object(Bucket=BUCKET_NAME, Key=alt_path)
            logger.info(f"Found file with uppercase extension: {alt_path}")
            return alt_path
        except:
            pass
    elif original_path.upper().endswith('.JPG'):
        alt_path = original_path[:-4] + '.jpg'
        try:
            s3_client.head_object(Bucket=BUCKET_NAME, Key=alt_path)
            logger.info(f"Found file with lowercase extension: {alt_path}")
            return alt_path
        except:
            pass
    
    # Strategy 3: Try to find file in organized structure
    filename = item.get('filename', file_id)
    if filename and filename != file_id:
        # Try current year/month structure
        current_date = datetime.now()
        organized_path = f"{user_id}/originals/{current_date.year}/{current_date.month:02d}/{filename}"
        try:
            s3_client.head_object(Bucket=BUCKET_NAME, Key=organized_path)
            logger.info(f"Found file in organized structure: {organized_path}")
            return organized_path
        except:
            pass
    
    # Strategy 4: Try direct file_id as filename
    direct_path = f"{user_id}/originals/{file_id}"
    try:
        s3_client.head_object(Bucket=BUCKET_NAME, Key=direct_path)
        logger.info(f"Found file with direct file_id: {direct_path}")
        return direct_path
    except:
        pass
    
    # Strategy 5: Try without originals folder
    root_path = f"{user_id}/{filename}" if filename else f"{user_id}/{file_id}"
    try:
        s3_client.head_object(Bucket=BUCKET_NAME, Key=root_path)
        logger.info(f"Found file in root user folder: {root_path}")
        return root_path
    except:
        pass
    
    logger.error(f"Could not find file {file_id} in any expected location")
    return None

def permanent_delete(user_id: str, file_ids: List[str]) -> List[Dict]:
    """Permanently delete files - Google Photos style"""
    results = []
    
    for file_id in file_ids:
        try:
            # Get file metadata
            response = table.get_item(
                Key={'user_id': user_id, 'file_id': file_id}
            )
            
            if 'Item' not in response:
                results.append({'file_id': file_id, 'success': False, 'error': 'File not found'})
                continue
            
            item = response['Item']
            
            # Get current path (could be in originals or trash)
            s3_paths = item.get('s3_paths', {})
            current_path = s3_paths.get('original', '')
            
            if not current_path:
                current_path = item.get('s3_key', '')
            
            # Delete from S3 (original or trash location)
            if current_path:
                try:
                    s3_client.delete_object(Bucket=BUCKET_NAME, Key=current_path)
                    logger.info(f"Deleted original file: {current_path}")
                except Exception as e:
                    logger.warning(f"Could not delete original {current_path}: {str(e)}")
            
            # Delete all thumbnails (both active and trash locations)
            thumbnails = item.get('thumbnails', {})
            
            for size in ['small', 'medium', 'large']:
                # Try current thumbnail path
                thumb_path = thumbnails.get(size, f"{user_id}/thumbnails/{size}/{file_id}_{size[0]}.webp")
                trash_thumb_path = f"{user_id}/trash/thumbnails/{size}/{file_id}_{size[0]}.webp"
                
                for path in [thumb_path, trash_thumb_path]:
                    try:
                        s3_client.delete_object(Bucket=BUCKET_NAME, Key=path)
                        logger.info(f"Deleted thumbnail: {path}")
                    except Exception as e:
                        logger.warning(f"Could not delete thumbnail {path}: {str(e)}")
            
            # Delete compressed version if exists
            compressed_path = s3_paths.get('compressed', f"{user_id}/compressed/{file_id}_compressed.jpg")
            try:
                s3_client.delete_object(Bucket=BUCKET_NAME, Key=compressed_path)
                logger.info(f"Deleted compressed: {compressed_path}")
            except Exception as e:
                logger.warning(f"Could not delete compressed {compressed_path}: {str(e)}")
            
            # Delete metadata from DynamoDB
            table.delete_item(
                Key={'user_id': user_id, 'file_id': file_id}
            )
            
            results.append({'file_id': file_id, 'success': True, 'action': 'permanently_deleted'})
            logger.info(f"Permanently deleted {file_id}")
            
        except Exception as e:
            logger.error(f"Error permanently deleting {file_id}: {str(e)}")
            results.append({'file_id': file_id, 'success': False, 'error': str(e)})
    
    return results

def restore_from_trash(user_id: str, file_ids: List[str]) -> List[Dict]:
    """Restore files from trash - Google Photos style"""
    results = []
    
    for file_id in file_ids:
        try:
            # Get file metadata
            response = table.get_item(
                Key={'user_id': user_id, 'file_id': file_id}
            )
            
            if 'Item' not in response:
                results.append({'file_id': file_id, 'success': False, 'error': 'File not found'})
                continue
            
            item = response['Item']
            
            # Check if file is actually in trash
            if item.get('processing_status') != 'trashed':
                results.append({'file_id': file_id, 'success': False, 'error': 'File not in trash'})
                continue
            
            s3_paths = item.get('s3_paths', {})
            trash_path = s3_paths.get('original', '')
            
            if not trash_path or '/trash/' not in trash_path:
                results.append({'file_id': file_id, 'success': False, 'error': 'Invalid trash path'})
                continue
            
            # Restore original file - reconstruct original path from file metadata
            file_info = item.get('file_info', {})
            year = file_info.get('year', datetime.now().year)
            month = file_info.get('month', f"{datetime.now().month:02d}")
            extension = file_info.get('extension', 'jpg')
            
            original_path = f"{user_id}/originals/{year}/{month}/{file_id}.{extension}"
            
            # Copy back to originals
            s3_client.copy_object(
                Bucket=BUCKET_NAME,
                CopySource={'Bucket': BUCKET_NAME, 'Key': trash_path},
                Key=original_path,
                Metadata={
                    'restored-date': datetime.utcnow().isoformat(),
                    'user-id': user_id,
                    'file-id': file_id
                },
                MetadataDirective='REPLACE'
            )
            
            # Delete from trash
            s3_client.delete_object(Bucket=BUCKET_NAME, Key=trash_path)
            
            # Restore thumbnails
            restored_thumbnails = {}
            for size in ['small', 'medium', 'large']:
                trash_thumb_path = f"{user_id}/trash/thumbnails/{size}/{file_id}_{size[0]}.webp"
                thumb_path = f"{user_id}/thumbnails/{size}/{file_id}_{size[0]}.webp"
                
                try:
                    s3_client.copy_object(
                        Bucket=BUCKET_NAME,
                        CopySource={'Bucket': BUCKET_NAME, 'Key': trash_thumb_path},
                        Key=thumb_path
                    )
                    s3_client.delete_object(Bucket=BUCKET_NAME, Key=trash_thumb_path)
                    restored_thumbnails[size] = thumb_path
                    logger.info(f"Restored thumbnail: {thumb_path}")
                except Exception as thumb_error:
                    logger.warning(f"Could not restore thumbnail {trash_thumb_path}: {str(thumb_error)}")
                    restored_thumbnails[size] = thumb_path  # Keep path for consistency
            
            # Update metadata - restore status
            updated_s3_paths = s3_paths.copy()
            updated_s3_paths['original'] = original_path
            
            table.update_item(
                Key={'user_id': user_id, 'file_id': file_id},
                UpdateExpression='SET processing_status = :status, s3_paths = :s3_paths, thumbnails = :thumbnails REMOVE trash_date',
                ExpressionAttributeValues={
                    ':status': 'completed',
                    ':s3_paths': updated_s3_paths,
                    ':thumbnails': restored_thumbnails
                }
            )
            
            results.append({'file_id': file_id, 'success': True, 'action': 'restored'})
            logger.info(f"Restored {file_id} from trash")
            
        except Exception as e:
            logger.error(f"Error restoring {file_id}: {str(e)}")
            results.append({'file_id': file_id, 'success': False, 'error': str(e)})
    
    return results

def list_trash_items(user_id: str) -> List[Dict]:
    """List all items in trash for user - Google Photos style"""
    try:
        # Query all user items and filter trashed ones
        response = table.query(
            KeyConditionExpression=Key('user_id').eq(user_id)
        )
        
        items = response.get('Items', [])
        trash_items = []
        
        for item in items:
            if item.get('processing_status') == 'trashed':
                # Calculate days in trash
                trash_date_str = item.get('trash_date', '')
                days_in_trash = 0
                
                if trash_date_str:
                    try:
                        trash_date = datetime.fromisoformat(trash_date_str.replace('Z', '+00:00'))
                        days_in_trash = (datetime.now() - trash_date.replace(tzinfo=None)).days
                    except:
                        pass
                
                # Generate thumbnail URL if available
                thumbnail_url = None
                thumbnails = item.get('thumbnails', {})
                if thumbnails.get('medium'):
                    try:
                        thumbnail_url = s3_client.generate_presigned_url(
                            'get_object',
                            Params={'Bucket': BUCKET_NAME, 'Key': thumbnails['medium']},
                            ExpiresIn=3600
                        )
                    except:
                        pass
                
                trash_item = {
                    'file_id': item.get('file_id'),
                    'original_filename': item.get('original_filename'),
                    'trash_date': trash_date_str,
                    'days_in_trash': days_in_trash,
                    'auto_delete_in_days': max(0, 30 - days_in_trash),  # Google Photos deletes after 30 days
                    'file_size': item.get('file_size'),
                    'content_type': item.get('content_type'),
                    'thumbnail_url': thumbnail_url,
                    'media_type': item.get('media_type', 'unknown')
                }
                trash_items.append(trash_item)
        
        # Sort by trash date (newest first)
        trash_items.sort(key=lambda x: x.get('trash_date', ''), reverse=True)
        
        return {
            'items': trash_items,
            'count': len(trash_items),
            'total_size_bytes': sum(item.get('file_size', 0) for item in items if item.get('processing_status') == 'trashed')
        }
        
    except Exception as e:
        logger.error(f"Error listing trash items for user {user_id}: {str(e)}")
        return {
            'items': [],
            'count': 0,
            'error': str(e)
        }
