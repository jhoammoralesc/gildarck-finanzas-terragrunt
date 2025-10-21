#!/bin/bash
set -e

# DNS Mapping Array
# Format: domain|hosted_zone_id|record_type|primary_value|secondary_value|ttl
readonly dns_mapping=(
    "valkey.prod.ibcobros.com|Z045092725J07J7BAHBHI|CNAME|valkey-prod-1.6le04k.ng.0001.use1.cache.amazonaws.com|valkey-prod-2.wc0tmo.ng.0001.use2.cache.amazonaws.com|60"
    "api.flexi.prod.ibcobros.com|Z045092725J07J7BAHBHI|CNAME|d2nig7wpe6k2pm.cloudfront.net|d-c3njooxxp0.execute-api.us-east-2.amazonaws.com|60"
    "api.prod.ibcobros.com|Z045092725J07J7BAHBHI|CNAME|d-8dc2sju7zj.execute-api.us-east-1.amazonaws.com|d-ih1rq167wc.execute-api.us-east-2.amazonaws.com|60"
    "ro.mysql-core.prod.ibcobros.com|Z045092725J07J7BAHBHI|CNAME|aurora-serverless-prod-mysql8-core.cluster-ro-cgslz384vubb.us-east-1.rds.amazonaws.com|global-cluster-core-cluster-1.cluster-ro-clewku2sk8d0.us-east-2.rds.amazonaws.com|60"
    "ro.mysql-flexibility.prod.ibcobros.com|Z045092725J07J7BAHBHI|CNAME|aurora-serverless-prod-mysql8-flexibility.cluster-ro-cgslz384vubb.us-east-1.rds.amazonaws.com|global-cluster-flexibility-cluster-1.cluster-ro-clewku2sk8d0.us-east-2.rds.amazonaws.com|60"
    "ro.mysql-fm.prod.ibcobros.com|Z045092725J07J7BAHBHI|CNAME|aurora-serverless-prod-mysql8-fm.cluster-ro-cgslz384vubb.us-east-1.rds.amazonaws.com|global-cluster-filemanager-cluster-1.cluster-ro-clewku2sk8d0.us-east-2.rds.amazonaws.com|60"
    "documentdb.prod.ibcobros.com|Z045092725J07J7BAHBHI|CNAME|prod-ic-document-db-1.cluster-cgslz384vubb.us-east-1.docdb.amazonaws.com|prod-ic-document-db-1.cluster-clewku2sk8d0.us-east-2.docdb.amazonaws.com|60"
    "redirect.ibcobros.com|Z07829323DBLMNSE34ZFV|CNAME|d195snennr6j0e.cloudfront.net|d-10ki54pi7f.execute-api.us-east-2.amazonaws.com|60"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error_exit() {
    echo "${RED}ERROR: $1${NC}" >&2
    exit 1
}

success_msg() {
    echo "${GREEN}$1${NC}"
}

warn_msg() {
    echo "${YELLOW}$1${NC}"
}

# DNS Changes Function
dns_changes() {
    local activation_mode="$1"
    
    # Display operation mode
    if [[ "$activation_mode" == "true" ]]; then
        warn_msg "ACTIVATING DRP: Switching DNS to SECONDARY region us-east-2"
    else
        warn_msg "DEACTIVATING DRP: Switching DNS to PRIMARY region us-east-1"
    fi
    
    echo ""
    read -p "Continue with DNS changes? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "DNS changes cancelled"
        return 1
    fi
    
    # Process each DNS record
    local failed_count=0
    local success_count=0
    
    for record in "${dns_mapping[@]}"; do
        IFS='|' read -r domain hosted_zone_id record_type primary_value secondary_value ttl <<< "$record"
        
        # Select target based on activation mode
        if [[ "$activation_mode" == "true" ]]; then
            target_value="$secondary_value"
        else
            target_value="$primary_value"
        fi
        
        echo "Updating $domain -> $target_value"
        
        # Create change batch JSON
        change_batch="{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$domain\",\"Type\":\"$record_type\",\"TTL\":$ttl,\"ResourceRecords\":[{\"Value\":\"$target_value\"}]}}]}"
        
        # Execute DNS update
        if aws route53 change-resource-record-sets \
            --hosted-zone-id "$hosted_zone_id" \
            --change-batch "$change_batch" \
            --output json --profile ic-prod > /dev/null 2>&1; then
            success_msg "✓ $domain updated successfully"
            ((success_count++))
        else
            error_exit "✗ Failed to update $domain"
            ((failed_count++))
        fi
    done
    
    echo ""
    if [[ $failed_count -eq 0 ]]; then
        success_msg "All $success_count DNS records updated successfully!"
        if [[ "$activation_mode" == "true" ]]; then
            success_msg "DNS switched to SECONDARY region us-east-2"
        else
            success_msg "DNS switched to PRIMARY region us-east-1"
        fi
        return 0
    else
        error_exit "Failed to update $failed_count DNS records"
    fi
}

# Main execution
main() {
    local activation_mode="$1"
    
    # Validate input parameter
    if [[ "$activation_mode" != "true" && "$activation_mode" != "false" ]]; then
        error_exit "Usage: $0 [true|false]
        true = Switch to secondary region (DR activation)
        false = Switch to primary region (normal operations)"
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI not found or not configured"
    fi
    
    echo "=========================================="
    echo "         DRP Activation Script"
    echo "=========================================="
    
    # Execute DNS changes
    dns_changes "$activation_mode"
    
    echo ""
    if [[ "$activation_mode" == "true" ]]; then
        success_msg "DRP ACTIVATION COMPLETED"
    else
        success_msg "DRP DEACTIVATION COMPLETED"
    fi
}

# Execute main function
main "$@"