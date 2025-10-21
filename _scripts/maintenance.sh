#!/bin/bash
# Previews is requered to be authenticated with the AWS CLI (aws sso login --profile ic-prod)
# Usage: ./maintenance.sh <true|false> <profile>
# Example for production: ./maintenance.sh true ic-prod
#
# Parameters:
#   - First parameter (true|false): Enable or disable maintenance mode
#   - Second parameter: AWS profile (for production use ic-prod)
#
# Description:
#   This script manages maintenance mode by:
#   - Modifying API Gateway authorizer
#   - Updating security group rules
#   - Managing kubernetes cronjobs
#   - Creating DB snapshots when enabling maintenance
if [ $# -ne 2 ]; then
    echo "Usage: $0 <true|false> <profile>"
    echo "For production use: $0 <true|false> ic-prod"
    exit 1
fi

MAINTENANCE=$1
PROFILE=$2
STAGE="${PROFILE#ic-}"

# Set default variables for PROD
SECURITY_GROUPS=("sg-027c20463c6f64a5a", "sg-0782b0722bd68afcd") # Core, FM PROD
API_ID="dcuddlocs1" # PROD
AUTHORIZER_ID="uxly4h" # PROD

# Override variables for UAT if needed
if [ "$STAGE" = "uat" ]; then
    SECURITY_GROUPS=("sg-0c37a7b9a02341267", "sg-0db85f6cf57cf4982") # Core, FM UAT
    API_ID="y9ura0omcf" # UAT
    AUTHORIZER_ID="43q6hr" # UAT
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query 'Account' --output text)
DB_CLUSTERS=("aurora-serverless-$STAGE-mysql8-core" "aurora-serverless-$STAGE-mysql8-fm")

modify_authorizer() {
    local action=$1
    local original_lambda_arn="arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:$AWS_ACCOUNT_ID:function:function-authorizer/invocations"
    local maintenance_lambda_arn="arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:$AWS_ACCOUNT_ID:function:function-authorizer-maintenance/invocations"

    if [ "$action" = "enable" ]; then
        response=$(aws apigateway update-authorizer \
            --profile "$PROFILE" \
            --rest-api-id "$API_ID" \
            --authorizer-id "$AUTHORIZER_ID" \
            --patch-operations \
                op=replace,path="/authorizerUri",value="${maintenance_lambda_arn}" \
            --output json)
        echo "Se actualizó el authorizer a modo mantenimiento"
    else
        response=$(aws apigateway update-authorizer \
            --profile "$PROFILE" \
            --rest-api-id "$API_ID" \
            --authorizer-id "$AUTHORIZER_ID" \
            --patch-operations \
                op=replace,path="/authorizerUri",value="${original_lambda_arn}" \
            --output json)
        echo "Se actualizó el authorizer al modo normal"
    fi

    deploy_response=$(aws apigateway create-deployment \
        --profile "$PROFILE" \
        --rest-api-id "$API_ID" \
        --stage-name "$STAGE" \
        --output json)
    echo "Se realizó el deployment de los cambios"
}

modify_security_groups() {
    local action=$1
    for sg in "${SECURITY_GROUPS[@]}"; do
        rules_response=$(aws ec2 describe-security-group-rules \
                --profile "$PROFILE" \
                    --filters "Name=group-id,Values=${sg%,}" \
            --query 'SecurityGroupRules[?IpProtocol==`tcp` && (FromPort==`3306` || FromPort==`80`)].[SecurityGroupRuleId,CidrIpv4,Description]' \
            --output json)

        echo "$rules_response" | jq -c '.[]' | while read -r rule; do
            rule_id=$(echo "$rule" | jq -r '.[0]')
            cidr=$(echo "$rule" | jq -r '.[1]')
            description=$(echo "$rule" | jq -r '.[2]')
        if [ "$action" = "enable" ]; then
                modify_response=$(aws ec2 modify-security-group-rules \
                --profile "$PROFILE" \
                --group-id "${sg%,}" \
                    --security-group-rules \
                    "SecurityGroupRuleId=$rule_id,\
                    SecurityGroupRule={\
                        IpProtocol=tcp,\
                        FromPort=80,\
                        ToPort=80,\
                        CidrIpv4=$cidr,\
                        Description=\"$description\"\
                    }" \
                --output json)
                echo "Se modificó la regla $rule_id del security group ${sg%,} a puerto 80"
        else
                modify_response=$(aws ec2 modify-security-group-rules \
                --profile "$PROFILE" \
                --group-id "${sg%,}" \
                    --security-group-rules \
                    "SecurityGroupRuleId=$rule_id,\
                    SecurityGroupRule={\
                        IpProtocol=tcp,\
                        FromPort=3306,\
                        ToPort=3306,\
                        CidrIpv4=$cidr,\
                        Description=\"$description\"\
                    }" \
                --output json)
                echo "Se modificó la regla $rule_id del security group ${sg%,} a puerto 3306"
                echo "Modified rule $rule_id of security group ${sg%,} to port 3306"
    fi
    done
    done
}

modify_cronjobs() {
    local action=$1
    local namespace="ibcobros-$STAGE"
    local context="eks-$STAGE-1"

    kubectl config use-context "$context"
    if [ $? -ne 0 ]; then
        echo "Error: No se pudo cambiar al contexto $context"
        echo "Error: Could not change to context $context"
    fi
    echo "Contexto de kubectl cambiado a: $context"
    echo "Kubectl context changed to: $context"
    CRONJOBS=($(kubectl get cronjobs -n "$namespace" --no-headers -o custom-columns=":metadata.name"))

    echo "Cronjobs encontrados en namespace $namespace:"
    echo "Cronjobs found in namespace $namespace:"
    for cronjob in "${CRONJOBS[@]}"; do
        echo "- $cronjob"
    done

    for cronjob in "${CRONJOBS[@]}"; do
        if [ "$action" = "enable" ]; then
            kubectl patch cronjob "$cronjob" -n "$namespace" -p '{"spec":{"suspend":true}}'
            echo "Cronjob $cronjob suspendido"
            echo "Cronjob $cronjob suspended"
        else
            kubectl patch cronjob "$cronjob" -n "$namespace" -p '{"spec":{"suspend":false}}'
            echo "Cronjob $cronjob reanudado"
            echo "Cronjob $cronjob resumed"
        fi
    done
}

create_db_snapshots() {
    local timestamp=$(date +%Y-%m-%d-%H-%M-%S)
    local snapshot_ids=()
    local snapshot_completed=()

    # Initiate snapshot creation
    for cluster in "${DB_CLUSTERS[@]}"; do
        snapshot_id="manual-snapshot-${cluster}-${timestamp}"
        create_response=$(aws rds create-db-cluster-snapshot \
            --profile "$PROFILE" \
            --db-cluster-identifier "$cluster" \
            --db-cluster-snapshot-identifier "$snapshot_id" \
            --output json)
        echo "Iniciando creación del snapshot $snapshot_id para el cluster $cluster"
        echo "Starting snapshot creation $snapshot_id for cluster $cluster"
        snapshot_ids+=("$snapshot_id")
        snapshot_completed+=(0)
    done

    # Monitor snapshot creation status
    echo "Esperando a que los snapshots se completen..."
    echo "Waiting for snapshots to complete..."

    while true; do
        all_available=true

        for i in "${!snapshot_ids[@]}"; do
            if [ "${snapshot_completed[$i]}" -eq 0 ]; then
                describe_response=$(aws rds describe-db-cluster-snapshots \
                    --profile "$PROFILE" \
                    --db-cluster-snapshot-identifier "${snapshot_ids[$i]}" \
                    --output json)
                status=$(echo "$describe_response" | jq -r '.DBClusterSnapshots[0].Status')

                if [ "$status" = "available" ]; then
                    echo "Snapshot ${snapshot_ids[$i]} completado exitosamente"
                    echo "Snapshot ${snapshot_ids[$i]} completed successfully"
                    snapshot_completed[$i]=1
                elif [ "$status" = "failed" ]; then
                    echo "Error: La creación del snapshot ${snapshot_ids[$i]} falló"
                    echo "Error: Snapshot creation ${snapshot_ids[$i]} failed"
                    exit 1
                else
                    all_available=false
                fi
            fi
        done

        if [ "$all_available" = true ]; then
            echo "Todos los snapshots han sido creados exitosamente"
            break
        fi

        sleep 30
    done
}

main() {
    if [ "$MAINTENANCE" = "true" ]; then
        echo "Iniciando modo mantenimiento..."
        modify_authorizer "enable"
        #modify_security_groups "enable"
        modify_cronjobs "enable"
        create_db_snapshots
        echo "Modo mantenimiento activado"
    elif [ "$MAINTENANCE" = "false" ]; then
        echo "Revirtiendo modo mantenimiento..."
        modify_authorizer "disable"
        #modify_security_groups "disable"
        modify_cronjobs "disable"
        echo "Modo mantenimiento desactivado"
    else
        echo "Parámetro inválido. Use true o false"
        exit 1
    fi
}

main
