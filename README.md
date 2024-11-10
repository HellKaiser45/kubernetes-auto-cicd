# Kubernetes CI/CD Workflow Template

## Overview
This project provides a comprehensive Kubernetes deployment and CI/CD workflow template using Argo Workflows and GitHub Actions.

## Prerequisites
- Kubernetes Cluster
- kubectl
- Argo Workflows
- GitHub Account
- Docker

## Repository Structure
- `deploy-and-workflow.sh`: Main deployment script
- `app-deploy.yaml`: Kubernetes deployment configuration
- `workflow/`:
  - `ci-workflow-template.yaml`: Workflow template for CI/CD
  - `cron-workflow.yaml`: Scheduled workflow configuration
  - `secrets-and-volumes-template.yaml`: Kubernetes secrets and service account setup

## Configuration Variables

### Key Files to Modify
1. `deploy-and-workflow.sh`
2. `workflow/cron-workflow.yaml`
3. `workflow/ci-workflow-template.yaml`

### Variables to Configure

#### In `deploy-and-workflow.sh`
- `SERVICE_NAME`: Name of your service
- `SERVICE_NAMESPACE`: Kubernetes namespace for deployment
- `GIT_USERNAME`: Your GitHub username
- `GIT_REPO_NAME`: Name of your GitHub repository
- `SERVICE_FOLDER_NAME`: Folder containing your service code
- `GIT_BRANCH`: Branch to monitor (default: main)
- `REGISTRY`: Container registry (default: ghcr.io)
- `DOCKER_USERNAME`: Docker/GitHub username
- `IMAGE_REPOSITORY`: Full image repository path
- `APP_NAME`: Application name for deployment
- `REPLICA_COUNT`: Number of pod replicas
- `SERVICE_PORT`: Service exposure port
- `CONTAINER_PORT`: Container internal port
- `SERVICE_TYPE`: Kubernetes service type
- `CONTAINER_NAME`: Name of the container
- `INGRESS_HOST`: Ingress hostname
- `CRON_SCHEDULE`: Workflow schedule (default: every 30 minutes)

#### In `workflow/secrets-and-volumes-template.yaml`
- Replace placeholders for GitHub and registry tokens

## Step-by-Step Setup

### 1. Clone the Repository
```bash
git clone <your-repository-url>
cd <repository-name>
```

### 2. Configure Variables
1. Open `deploy-and-workflow.sh`
2. Replace all `your-*` placeholders with your specific project details
3. Ensure all paths and names are correct

### 3. Set Up Secrets
1. Open `workflow/secrets-and-volumes-template.yaml`
2. Replace `your github token` with a GitHub Personal Access Token
3. Replace `your registry token` with your container registry token

### 4. Deploy Workflow
```bash
# Make script executable
chmod +x deploy-and-workflow.sh

# Run deployment script
./deploy-and-workflow.sh
```

## Workflow Explanation
- Checks for version changes in specified repository
- Clones repository if changes detected
- Builds and pushes container image
- Restarts deployment in Kubernetes

## Customization
- Modify workflow steps in `workflow/ci-workflow-template.yaml`
- Adjust deployment configuration in `app-deploy.yaml`

## License
This project is licensed under the MIT License. See `LICENSE` for details.

## Troubleshooting
- Ensure all tokens and credentials are correct
- Verify Kubernetes cluster access
- Check Argo Workflows installation

## Contributing
Contributions are welcome! Please submit a Pull Request.
