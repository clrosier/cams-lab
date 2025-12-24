# Actions Runner Controller (ARC)

GitHub Actions self-hosted runners running in your Kubernetes cluster for building and deploying applications.

## Overview

This setup deploys [Actions Runner Controller](https://github.com/actions/actions-runner-controller) (ARC) to manage GitHub Actions runners in your Kubernetes cluster. Runners can execute GitHub Actions workflows directly in your cluster, enabling you to build container images, run tests, and deploy applications.

## Components

- **Actions Runner Controller**: Kubernetes operator that manages runner pods
- **RunnerDeployment**: Defines runner configuration for `cameronrosier/cams-lab` repository
- **GitHub PAT Secret**: Personal Access Token for authenticating with GitHub

## Setup Instructions

### 1. Create GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Give it a descriptive name (e.g., "ARC Kubernetes Runner")
4. Select the following scopes:
   - `repo` (Full control of private repositories) - **Required**
   - `admin:org` (if using organization-level runners) - **Optional**
   - `read:org` (if using organization-level runners) - **Optional**
5. Click "Generate token" and **copy the token immediately** (you won't see it again)

### 2. Encrypt GitHub PAT Secret

1. Edit `github-secret.yaml` and replace `YOUR_GITHUB_PAT_TOKEN_HERE` with your actual token
2. Encrypt the secret with SOPS:
   ```bash
   source scripts/sops-env.sh
   sops --encrypt --in-place clusters/home/infra/actions-runner-controller/github-secret.yaml
   ```

### 3. Deploy with Flux

Once the secret is encrypted and committed, Flux will automatically deploy:

```bash
# Check deployment status
flux get helmreleases -n actions-runner-system

# Check runner pods
kubectl get pods -n actions-runner-system

# Check runner deployment
kubectl get runnerdeployment -n actions-runner-system
```

### 4. Verify Runner Registration

1. Go to your repository: https://github.com/cameronrosier/cams-lab
2. Navigate to **Settings** → **Actions** → **Runners**
3. You should see a runner with labels: `self-hosted`, `kubernetes`, `robopd2`

## Using Runners in GitHub Actions

Create a workflow file (e.g., `.github/workflows/build.yml`) that uses your self-hosted runner:

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: [self-hosted, robopd2]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Build Docker image
        run: |
          docker build -t robopd2-api:latest ./api
          docker build -t robopd2-web:latest ./web
      
      - name: Push to registry
        run: |
          # Add your registry push commands here
          echo "Push images to registry"
```

## Runner Configuration

### Current Setup

- **Repository**: `cameronrosier/cams-lab`
- **Replicas**: 1 runner pod
- **Labels**: `self-hosted`, `kubernetes`, `robopd2`
- **Resources**: 
  - Requests: 500m CPU, 1Gi memory
  - Limits: 2000m CPU, 4Gi memory
- **Docker**: Mounts host Docker socket for building images

### Customization

Edit `runnerdeployment.yaml` to:

- **Change repository**: Update the `repository` field
- **Use organization runners**: Replace `repository` with `organization: your-org`
- **Scale runners**: Change `replicas` value
- **Add labels**: Modify the `labels` array
- **Adjust resources**: Update `resources` section

### Multiple Runner Deployments

You can create multiple `RunnerDeployment` resources for different repositories or use cases:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: another-runner
  namespace: actions-runner-system
spec:
  replicas: 1
  template:
    spec:
      repository: cameronrosier/another-repo
      labels:
        - self-hosted
        - kubernetes
```

## Troubleshooting

### Runner Not Appearing in GitHub

1. Check the controller logs:
   ```bash
   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller
   ```

2. Verify the secret exists and is correct:
   ```bash
   kubectl get secret github-pat -n actions-runner-system
   ```

3. Check runner pod logs:
   ```bash
   kubectl logs -n actions-runner-system -l runner-deployment-name=robopd2-runner
   ```

### Runner Pod Not Starting

1. Check pod status:
   ```bash
   kubectl describe pod -n actions-runner-system -l runner-deployment-name=robopd2-runner
   ```

2. Verify resources are available:
   ```bash
   kubectl top nodes
   kubectl top pods -n actions-runner-system
   ```

### Jobs Not Running on Runner

1. Verify the workflow uses the correct labels:
   ```yaml
   runs-on: [self-hosted, robopd2]
   ```

2. Check runner status in GitHub UI (Settings → Actions → Runners)

3. Ensure the runner is "Online" and "Idle"

## Security Considerations

- **PAT Token**: Store the GitHub PAT securely using SOPS encryption
- **Docker Socket**: Mounting the host Docker socket gives runners full Docker access. Consider using Docker-in-Docker or Kaniko for builds
- **Resource Limits**: Runners have resource limits to prevent resource exhaustion
- **Network Policies**: Consider adding network policies to restrict runner network access

## Advanced: Using GitHub App (Recommended for Production)

For production environments, consider using GitHub App authentication instead of PAT tokens:

1. Create a GitHub App in your organization
2. Install the app on your repositories
3. Configure ARC to use the GitHub App credentials

See [ARC GitHub App documentation](https://github.com/actions/actions-runner-controller/blob/master/docs/authenticating-to-github.md#github-app-authentication) for details.

## Resources

- [Actions Runner Controller Documentation](https://github.com/actions/actions-runner-controller)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [ARC Helm Chart](https://github.com/actions/actions-runner-controller/tree/master/charts/actions-runner-controller)

