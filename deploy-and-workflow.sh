#!/bin/bash
set -euo pipefail

# Comprehensive Deployment Configuration
# ======================================

# Core Service Configuration
export SERVICE_NAME=your-service-name
export SERVICE_NAMESPACE=your-namespace

# GitHub Repository Details
export GIT_USERNAME=your-github-username
export GIT_REPO_NAME=your-repo-name
export SERVICE_FOLDER_NAME=your-service-folder
export GIT_BRANCH=main

# Container Registry Details
export REGISTRY=ghcr.io
export DOCKER_USERNAME=your-docker-username
export IMAGE_REPOSITORY="${REGISTRY}/${DOCKER_USERNAME}/${SERVICE_FOLDER_NAME}"
export IMAGE_TAG=latest

# Deployment Configuration
export APP_NAME="your-app-name"
export REPLICA_COUNT=2
export SERVICE_PORT=80
export CONTAINER_PORT=80
export SERVICE_TYPE="ClusterIP"
export CONTAINER_NAME="your-container-name"

# Networking Configuration
export INGRESS_HOST="your-service.your-domain.dev"
export SITE_ORIGIN="${INGRESS_HOST}"
export INGRESS_PATH_TYPE="Prefix"
export INGRESS_PATH="/"

# Workflow Configuration
export CRON_SCHEDULE="*/30 * * * *"  # Every 30 minutes
export WORKFLOW_TEMPLATE_NAME="${SERVICE_NAME}-ci-template"

# Image Pull Configuration
export IMAGE_PULL_SECRET="github-registry-secret"

# Rest of the script remains the same as in the previous version...
# (Keeping all the existing functions and logic)

# Logging function with enhanced debugging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Detailed error handling function
handle_error() {
    local line_number=$1
    local command="$2"
    log "ERROR: Command failed at line $line_number"
    log "Command: $command"
    log "Error details:"
    set +e
    $command 2>&1 | log
    set -e
    exit 1
}

# Trap errors with line number and command
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Sanitize names for Kubernetes compatibility
SAFE_SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
SAFE_SERVICE_NAMESPACE=$(echo "$SERVICE_NAMESPACE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')

# Advanced PVC Cleanup Function with Extensive Logging
cleanup_pvc() {
    local namespace=$1
    local pvc_name=$2

    log "Attempting to cleanup PVC: $pvc_name in namespace $namespace"

    # Detailed logging of current state
    log "Current PVC status:"
    kubectl get pvc "$pvc_name" -n "$namespace" || true

    # List all pods in the namespace
    log "Listing pods in namespace $namespace:"
    kubectl get pods -n "$namespace" || true

    # Find and delete pods using the PVC
    local pods=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}')

    for pod in $pods; do
        if kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}' | grep -q "$pvc_name"; then
            log "Deleting pod $pod using PVC $pvc_name"
            kubectl delete pod "$pod" -n "$namespace" --grace-period=0 --force 2>/dev/null || true
        fi
    done

    # Remove finalizers and force delete PVC
    log "Removing PVC finalizers..."
    kubectl patch pvc "$pvc_name" -n "$namespace" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

    log "Force deleting PVC..."
    kubectl delete pvc "$pvc_name" -n "$namespace" --grace-period=0 --force 2>/dev/null || true

    # Delete associated Persistent Volumes
    local pvs=$(kubectl get pv | grep "$pvc_name" | awk '{print $1}')
    for pv in $pvs; do
        log "Deleting associated Persistent Volume: $pv"
        kubectl delete pv "$pv" --grace-period=0 --force 2>/dev/null || true
    done

    log "PVC cleanup completed for $pvc_name"
}

# Workflow and Resource Deployment with Detailed Logging
deploy_workflows() {
    log "Creating namespace $SAFE_SERVICE_NAMESPACE..."
    kubectl create namespace "$SAFE_SERVICE_NAMESPACE" 2>/dev/null || true

    # Cleanup existing resources
    log "Cleaning up Persistent Volume Claims..."
    cleanup_pvc "$SAFE_SERVICE_NAMESPACE" "version-pvc"

    log "Cleaning up existing resources..."
    kubectl delete -n "$SAFE_SERVICE_NAMESPACE" secrets git-credentials registry-credentials github-registry-secret 2>/dev/null || true
    kubectl delete -n "$SAFE_SERVICE_NAMESPACE" serviceaccount "$SAFE_SERVICE_NAME-workflow-sa" 2>/dev/null || true
    kubectl delete -n "$SAFE_SERVICE_NAMESPACE" clusterrole "$SAFE_SERVICE_NAME-workflow-role" 2>/dev/null || true
    kubectl delete -n "$SAFE_SERVICE_NAMESPACE" clusterrolebinding "$SAFE_SERVICE_NAME-workflow-rolebinding" 2>/dev/null || true
    kubectl delete -n "$SAFE_SERVICE_NAMESPACE" workflow --all 2>/dev/null || true
    kubectl delete -n "$SAFE_SERVICE_NAMESPACE" cronworkflow "$SAFE_SERVICE_NAME-repo-monitor" 2>/dev/null || true

    # Apply secrets and volumes
    log "Applying secrets and volumes..."
    envsubst < workflow/secrets-and-volumes-template.yaml | kubectl apply -n "$SAFE_SERVICE_NAMESPACE" -f - || {
        log "Failed to apply secrets and volumes"
        return 1
    }

    # Create workflow template
    log "Creating workflow template..."
    envsubst < workflow/ci-workflow-template.yaml | kubectl create -n "$SAFE_SERVICE_NAMESPACE" -f - 2>/dev/null || true

    # Create cron workflow
    log "Creating cron workflow..."
    envsubst < workflow/cron-workflow.yaml | kubectl create -n "$SAFE_SERVICE_NAMESPACE" -f - 2>/dev/null || true

    log "Workflows applied successfully!"
}

# Application Deployment with Enhanced Error Handling
deploy_application() {
    log "Starting application deployment..."

    # Temporary file for processed configuration
    TEMP_CONFIG=$(mktemp)

    # Create a copy of the original configuration
    cp app-deploy.yaml "$TEMP_CONFIG"

    # Use envsubst to replace variables
    envsubst < "$TEMP_CONFIG" > "${TEMP_CONFIG}.processed"

    # Validate the modified configuration
    log "Validating application configuration..."
    if ! kubectl apply -f "${TEMP_CONFIG}.processed" --dry-run=client; then
        log "Configuration validation failed"
        cat "${TEMP_CONFIG}.processed"
        rm "$TEMP_CONFIG" "${TEMP_CONFIG}.processed"
        return 1
    fi

    # Deploy the configuration
    log "Applying application configuration..."
    kubectl apply -f "${TEMP_CONFIG}.processed" || {
        log "Failed to apply application configuration"
        return 1
    }

    # Clean up temporary files
    rm "$TEMP_CONFIG" "${TEMP_CONFIG}.processed"

    log "Application deployed successfully!"
}

# Main Deployment Workflow with Error Handling
main() {
    log "Starting deployment process..."

    deploy_workflows || {
        log "Workflow deployment failed"
        exit 1
    }

    deploy_application || {
        log "Application deployment failed"
        exit 1
    }

    log "Deployment completed successfully!"
}

# Execute main deployment
main
