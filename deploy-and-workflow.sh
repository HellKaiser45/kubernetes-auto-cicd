#!/bin/bash
set -euo pipefail

# Comprehensive Deployment Configuration
# ======================================
export CONTAINER_NAME="your-container-name"
# Core Service Configuration
export SERVICE_NAME=$CONTAINER_NAME
export SERVICE_NAMESPACE=your-namespace

# GitHub Repository Details
export GIT_USERNAME=your-github-username
export GIT_REPO_NAME=your-repo-name
export SERVICE_FOLDER_NAME=your-service-folder
export GIT_BRANCH=main

# Deployment Configuration
export APP_NAME=$CONTAINER_NAME
export REPLICA_COUNT=2
export SERVICE_PORT=80
export CONTAINER_PORT=80
export SERVICE_TYPE="ClusterIP"


# Container Registry Details
export REGISTRY=ghcr.io
export DOCKER_USERNAME=your-docker-username
export IMAGE_REPOSITORY="${REGISTRY}/${DOCKER_USERNAME}/${CONTAINER_NAME}"
export IMAGE_TAG=latest

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

# Advanced PVC Cleanup Function with Simplified Deletion
cleanup_pvc() {

    log "Attempting to cleanup PVC: $SERVICE_NAME-version-pvc in namespace $SERVICE_NAMESPACE"

    # Simplified PVC deletion
    log "Deleting PVC $SERVICE_NAME-version-pvc in namespace $SERVICE_NAMESPACE"
    kubectl delete pvc $SERVICE_NAME-version-pvc -n $SERVICE_NAMESPACE 2>/dev/null || true


    log "PVC cleanup completed for $SERVICE_NAME-version-pvc"
}

# New function to delete pods, deployments, and services
delete_resources() {
    log "Deleting resources in namespace $SERVICE_NAMESPACE..."

    log "Deleting services "$APP_NAME""
    kubectl delete services "$APP_NAME" -n "$SERVICE_NAMESPACE" 2>/dev/null || true

    # Delete deployments
    log "Deleting deployments "$APP_NAME""
    kubectl delete deployments "$APP_NAME" -n "$SERVICE_NAMESPACE" 2>/dev/null || true

    log "Deleting ingress $APP_NAME-ingress"
    kubectl delete ingress $APP_NAME-ingress -n "$SERVICE_NAMESPACE" 2>/dev/null || true

    # Delete workflows and cronworkflows
    log "Deleting all workflowtemplates and cronworkflows..."
    kubectl delete workflowtemplates $SERVICE_NAME-ci-template -n "$SERVICE_NAMESPACE" 2>/dev/null || true
    kubectl delete cronworkflows $SERVICE_NAME-repo-monitor -n "$SERVICE_NAMESPACE" 2>/dev/null || true

    log "Deleting secrets"
    kubectl delete -n "$SERVICE_NAMESPACE" secrets git-credentials registry-credentials github-registry-secret 2>/dev/null || true

    log "Deleting service account"
    kubectl delete -n "$SERVICE_NAMESPACE" serviceaccount "$SERVICE_NAME-workflow-sa" 2>/dev/null || true

    log "Deleting cluster role and binding"
    kubectl delete -n "$SERVICE_NAMESPACE" clusterrole "$SERVICE_NAME-workflow-role" 2>/dev/null || true
    kubectl delete -n "$SERVICE_NAMESPACE" clusterrolebinding "$SERVICE_NAME-workflow-rolebinding" 2>/dev/null || true

    log "Resource deletion completed in namespace $SERVICE_NAMESPACE"
}

# Workflow and Resource Deployment with Detailed Logging
deploy_workflows() {

    # Apply secrets and volumes
    log "Applying secrets and volumes..."
    envsubst < workflow/secrets-and-volumes-template.yaml | kubectl apply -n "$SERVICE_NAMESPACE" -f - || {
        log "Failed to apply secrets and volumes"
        return 1
    }

    # Create workflow template
    log "Creating workflow template..."
    envsubst < workflow/ci-workflow-template.yaml | kubectl create -n "$SERVICE_NAMESPACE" -f - 2>/dev/null || true

    # Create cron workflow
    log "Creating cron workflow..."
    envsubst < workflow/cron-workflow.yaml | kubectl create -n "$SERVICE_NAMESPACE" -f - 2>/dev/null || true

    log "Workflows applied successfully!"
}

# Application Deployment with Enhanced Error Handling
deploy_application() {
    log "Starting application deployment..."

    envsubst < app-deploy.yaml | kubectl apply -n "$SERVICE_NAMESPACE" -f - || {
        log "Failed to deploy"
        return 1
    }

    log "Application deployed successfully!"
}

# Main Deployment Workflow with Error Handling
main() {
    log "Creating namespace $SERVICE_NAMESPACE..."
    kubectl create namespace "$SERVICE_NAMESPACE" 2>/dev/null || true

    log "Cleaning up existing resources..."
    delete_resources

    log "Cleaning up Persistent Volume Claims..."
    cleanup_pvc

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
main "$@"
