# GitHub Actions Workflow Documentation

## Workflow: Deploy Azure Hub Network

### Overview

The `deploy-hub-network.yml` workflow provides a complete CI/CD pipeline for deploying Azure hub networking infrastructure.

### Workflow Features

- ✅ Manual trigger with parameters
- ✅ Support for multiple environments (dev, prod)
- ✅ Three deployment modes (validate, what-if, deploy)
- ✅ Bicep template validation
- ✅ Azure authentication using OIDC (federated identity)
- ✅ VPN configuration extraction and artifact upload
- ✅ Deployment summary with outputs

### Workflow Inputs

| Input | Type | Description | Options | Default |
|-------|------|-------------|---------|---------|
| `environment` | choice | Target environment | dev, prod | dev |
| `action` | choice | Deployment action | validate, what-if, deploy | validate |

### Workflow Steps

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Checkout Code                                             │
│    Uses: actions/checkout@v4                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Azure Login                                               │
│    Uses: azure/login@v2                                      │
│    Auth: OIDC with federated identity                        │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Validate Bicep Templates                                  │
│    Runs: az bicep build                                      │
│    Validates: main.bicep and all modules                     │
│    Condition: action == 'validate' OR action == 'deploy'     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Run What-If Deployment                                    │
│    Runs: az deployment sub what-if                           │
│    Shows: Changes that would be made                         │
│    Condition: action == 'what-if' OR action == 'deploy'      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Deploy Infrastructure                                     │
│    Runs: az deployment sub create                            │
│    Creates: All Azure resources                              │
│    Outputs: Saved to deployment-output.json                  │
│    Condition: action == 'deploy'                             │
│    Duration: ~35-50 minutes                                  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Extract VPN Configuration                                 │
│    Extracts: VPN Gateway details, DNS Resolver IP            │
│    Creates: vpn-configuration.txt                            │
│    Condition: action == 'deploy'                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Upload VPN Configuration                                  │
│    Uses: actions/upload-artifact@v4                          │
│    Artifact: vpn-configuration-{environment}                 │
│    Retention: 90 days                                        │
│    Condition: action == 'deploy'                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Summary                                                    │
│    Displays: Deployment summary with all outputs             │
│    Format: Markdown table in workflow summary                │
│    Condition: action == 'deploy'                             │
└─────────────────────────────────────────────────────────────┘
```

### Required Secrets

The workflow requires three repository secrets:

| Secret | Description | How to Obtain |
|--------|-------------|---------------|
| `AZURE_CLIENT_ID` | Service Principal Application ID | Created with `az ad sp create-for-rbac` |
| `AZURE_TENANT_ID` | Azure Active Directory Tenant ID | From Azure Portal or CLI |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription ID | From Azure Portal or `az account show` |

### Permissions

The workflow uses the following permissions:

```yaml
permissions:
  id-token: write    # Required for OIDC authentication
  contents: read     # Required to checkout code
```

### Environment Configuration

Environments can be configured in GitHub repository settings to add:
- Protection rules
- Required reviewers
- Deployment branches
- Secrets specific to each environment

### Usage Examples

#### Example 1: Validate Templates Only

```yaml
Trigger: Manual workflow_dispatch
Inputs:
  environment: dev
  action: validate
  
Result: 
  - Templates validated
  - No Azure resources created
  - Duration: ~30 seconds
```

#### Example 2: Preview Changes

```yaml
Trigger: Manual workflow_dispatch
Inputs:
  environment: prod
  action: what-if
  
Result:
  - Templates validated
  - What-if analysis displayed
  - No Azure resources created
  - Duration: ~1-2 minutes
```

#### Example 3: Deploy to Development

```yaml
Trigger: Manual workflow_dispatch
Inputs:
  environment: dev
  action: deploy
  
Result:
  - All validation steps run
  - What-if analysis shown
  - Resources deployed to Azure
  - VPN config uploaded as artifact
  - Duration: ~35-50 minutes
```

#### Example 4: Deploy to Production

```yaml
Trigger: Manual workflow_dispatch
Inputs:
  environment: prod
  action: deploy
  
Result:
  - (Same as dev deployment)
  - May require approval if configured
  - Uses prod parameter file
  - Duration: ~35-50 minutes
```

### Workflow Outputs

After a successful deployment, the workflow provides:

1. **Deployment Summary** (in workflow summary)
   - Resource Group name
   - Virtual Network name
   - VPN Gateway name and Public IP
   - DNS Resolver Inbound IP

2. **VPN Configuration Artifact** (downloadable)
   - Complete VPN setup instructions
   - Gateway details
   - Connection commands
   - Retention: 90 days

3. **Deployment Output JSON** (in workflow logs)
   - Full Azure deployment response
   - All resource IDs
   - All outputs from Bicep templates

### Customization Options

#### Change Azure Region

Edit the workflow file:
```yaml
env:
  AZURE_REGION: westus2  # Change from eastus
```

#### Add More Environments

1. Create new parameter file: `infra/parameters/staging.parameters.json`
2. Update workflow inputs:
```yaml
options:
  - dev
  - staging
  - prod
```

#### Add Approval Gates

1. Go to Settings → Environments
2. Select environment (e.g., prod)
3. Enable "Required reviewers"
4. Add reviewer GitHub usernames

#### Add Scheduled Deployments

Add to workflow triggers:
```yaml
on:
  workflow_dispatch:
    # ... existing inputs
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday at midnight
```

### Monitoring and Debugging

#### View Workflow Runs

1. Go to **Actions** tab
2. Click on workflow run
3. Expand each step to see logs

#### Debug Mode

Enable debug logging:
1. Go to Settings → Secrets → Actions
2. Add secret: `ACTIONS_STEP_DEBUG` = `true`
3. Re-run workflow

#### Download Logs

Click "Download log archive" button on workflow run page.

### Error Handling

The workflow includes error handling for common scenarios:

| Error | Cause | Solution |
|-------|-------|----------|
| Authentication failed | Invalid secrets | Check AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID |
| Template validation failed | Syntax error in Bicep | Review Bicep files, run `az bicep build` locally |
| Deployment timeout | VPN Gateway takes too long | Normal behavior, wait up to 45 minutes |
| Insufficient permissions | Service Principal lacks access | Grant Contributor role at subscription level |
| Resource already exists | Redeployment of same resources | Normal, deployment is idempotent |

### Best Practices

1. **Always validate first**
   - Run with action: `validate` before deploying

2. **Use what-if for production**
   - Preview changes with action: `what-if` before prod deployment

3. **Enable environment protection for prod**
   - Require manual approval for production deployments

4. **Monitor costs**
   - VPN Gateway is the most expensive component (~$140-380/month)
   - Delete dev environments when not in use

5. **Version control**
   - Always commit parameter changes before deploying
   - Use meaningful commit messages

6. **Artifacts retention**
   - VPN configuration artifacts kept for 90 days
   - Download and store securely

### Troubleshooting Commands

Run these in Azure Cloud Shell if workflow fails:

```bash
# Check deployment status
az deployment sub show \
  --name hub-network-dev-20240115-103000 \
  --query properties.provisioningState

# View deployment errors
az deployment sub show \
  --name hub-network-dev-20240115-103000 \
  --query properties.error

# List operations
az deployment operation sub list \
  --name hub-network-dev-20240115-103000 \
  --query "[?properties.provisioningState=='Failed']"

# Re-run deployment manually
az deployment sub create \
  --location eastus \
  --template-file infra/bicep/main.bicep \
  --parameters infra/parameters/dev.parameters.json \
  --name hub-network-dev-manual
```

### Security Considerations

1. **Secrets Management**
   - Never commit secrets to repository
   - Use GitHub encrypted secrets
   - Rotate Service Principal credentials regularly

2. **OIDC Authentication**
   - Preferred over Service Principal password
   - No long-lived credentials stored
   - Automatic token expiration

3. **Least Privilege**
   - Service Principal has only Contributor role
   - Scoped to specific subscription

4. **Audit Logging**
   - All deployments logged in Azure Activity Log
   - GitHub Actions provides complete audit trail

### Performance Optimization

1. **Parallel Deployments**
   - VPN Gateway and DNS Resolver deploy in parallel
   - Reduces total deployment time

2. **Incremental Deployments**
   - Bicep uses incremental mode by default
   - Only changed resources are updated

3. **Artifact Caching**
   - Workflow uses latest action versions
   - Leverages GitHub Actions cache

### CI/CD Pipeline Integration

This workflow can be integrated into a larger pipeline:

```yaml
# Example: Deploy hub, then spoke networks
jobs:
  deploy-hub:
    uses: ./.github/workflows/deploy-hub-network.yml
    
  deploy-spokes:
    needs: deploy-hub
    uses: ./.github/workflows/deploy-spoke-networks.yml
```

### Future Enhancements

Potential improvements:
- [ ] Add terraform plan comparison
- [ ] Integrate with Azure Cost Management API
- [ ] Add automated testing with Pester
- [ ] Send notifications to Teams/Slack
- [ ] Add drift detection
- [ ] Implement blue/green deployments
