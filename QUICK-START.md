# Quick Start Guide

This guide will help you get your Azure Hub Network deployed in minutes.

## Prerequisites Checklist

Before you begin, make sure you have:

- [ ] An active Azure subscription
- [ ] Owner or Contributor access to the subscription
- [ ] A GitHub account with access to this repository
- [ ] Azure CLI installed (for local setup only)

## Setup Steps

### 1. Create Azure Service Principal

Run these commands in Azure Cloud Shell or local terminal:

```bash
# Set your subscription ID
SUBSCRIPTION_ID="your-subscription-id-here"

# Create Service Principal with federated credentials
az ad sp create-for-rbac \
  --name "github-azure-hub-network" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --query "{clientId:appId, tenantId:tenant}" \
  --output json

# Save the output - you'll need:
# - clientId (AZURE_CLIENT_ID)
# - tenantId (AZURE_TENANT_ID)
# - subscriptionId (AZURE_SUBSCRIPTION_ID)
```

### 2. Configure GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:
   - Name: `AZURE_CLIENT_ID` / Value: (from step 1)
   - Name: `AZURE_TENANT_ID` / Value: (from step 1)
   - Name: `AZURE_SUBSCRIPTION_ID` / Value: (your subscription ID)

### 3. Configure Federated Identity (Recommended)

This allows GitHub Actions to authenticate without storing passwords:

```bash
# Get your Application ID from step 1
APP_ID="your-client-id-here"

# Get your repository info
GITHUB_OWNER="your-github-username"
GITHUB_REPO="azure-hub-network-setup"

# Create federated credential
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-deploy",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_OWNER'/'$GITHUB_REPO':ref:refs/heads/main",
    "description": "GitHub Actions deployment",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 4. Create GitHub Environments (Optional but Recommended)

1. Go to **Settings** → **Environments**
2. Create two environments:
   - `dev` (for development/testing)
   - `prod` (for production)
3. For `prod`, enable required reviewers to add approval gates

## First Deployment

### Option A: Validate First (Recommended)

1. Go to **Actions** tab
2. Select **Deploy Azure Hub Network**
3. Click **Run workflow**
4. Choose:
   - Environment: `dev`
   - Action: `validate`
5. Click **Run workflow**
6. Wait ~30 seconds for validation to complete

### Option B: What-If Analysis

1. Same as above, but choose Action: `what-if`
2. Review the changes that would be made
3. No resources will be created

### Option C: Full Deployment

1. Same as above, but choose Action: `deploy`
2. Wait ~35-50 minutes for deployment
3. Download VPN configuration from artifacts

## After Deployment

### Download VPN Configuration

1. Go to the completed workflow run
2. Scroll to bottom → **Artifacts**
3. Download `vpn-configuration-dev`
4. Open the file to see your VPN Gateway details

### View Deployed Resources

```bash
# List all resources in the resource group
az resource list \
  --resource-group rg-hub-network-dev \
  --output table

# Get VPN Gateway details
az network vnet-gateway show \
  --resource-group rg-hub-network-dev \
  --name vpngw-hub-dev \
  --output table
```

### Test DNS Resolver

```bash
# Get DNS Resolver inbound IP
az network private-dns-resolver inbound-endpoint show \
  --dns-resolver-name dnspr-hub-dev \
  --resource-group rg-hub-network-dev \
  --name inbound-endpoint \
  --query ipConfigurations[0].privateIpAddress -o tsv
```

## Local Development

### Validate Templates Locally

```bash
# Clone the repository
git clone https://github.com/anotherRedbeard/azure-hub-network-setup.git
cd azure-hub-network-setup

# Run validation script
./validate-deployment.sh
```

### Deploy Locally

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Deploy to dev
az deployment sub create \
  --location eastus \
  --template-file infra/bicep/main.bicep \
  --parameters infra/parameters/dev.parameters.json \
  --name "hub-network-dev-$(date +%Y%m%d-%H%M%S)"
```

## Common First-Time Issues

### "Authentication failed"
**Solution**: Double-check all three secrets are set correctly in GitHub repository settings.

### "Insufficient permissions"
**Solution**: Ensure the Service Principal has Contributor role:
```bash
az role assignment create \
  --assignee <CLIENT_ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

### "Subnet already exists"
**Solution**: The deployment is idempotent. If re-deploying, it will update existing resources.

### "Location not available"
**Solution**: Change location in parameter file to a region where all services are available (eastus, westus2, northeurope, etc.)

## Next Steps

After your first successful deployment:

1. **Configure On-Premises VPN**
   - Follow instructions in `DEPLOYMENT-EXAMPLES.md`
   - Create Local Network Gateway
   - Establish VPN connection

2. **Set Up DNS Forwarding**
   - Configure DNS forwarding rules
   - Test name resolution

3. **Deploy to Production**
   - Review prod parameters
   - Run what-if first
   - Deploy with approval (if configured)

4. **Add Spoke Networks**
   - Create spoke VNets
   - Set up VNet peering
   - Configure routing

## Getting Help

- Review `README.md` for detailed documentation
- Check `DEPLOYMENT-EXAMPLES.md` for usage examples
- Review `infra/RESOURCES.md` for resource details
- Open an issue on GitHub for bugs or feature requests

## Cost Management

Monitor your costs:

```bash
# View cost for the resource group
az consumption usage list \
  --resource-group rg-hub-network-dev \
  --start-date 2024-01-01 \
  --end-date 2024-01-31
```

### Reduce Costs for Dev

To reduce costs in development:
1. Stop/deallocate the VPN Gateway when not in use:
   ```bash
   # Note: VPN Gateway cannot be stopped, you must delete and recreate
   # Or use a lower SKU in dev (VpnGw1 instead of VpnGw2)
   ```

2. Use smaller SKUs in dev environment (already configured)
3. Delete dev environment when not needed:
   ```bash
   az group delete --name rg-hub-network-dev --yes --no-wait
   ```

## Congratulations! 🎉

You now have a production-ready Azure Hub Network with:
- ✅ Virtual Network with proper subnets
- ✅ VPN Gateway for site-to-site connectivity
- ✅ Private DNS Resolver for DNS resolution
- ✅ Automated deployment pipeline
- ✅ Infrastructure as Code with Bicep

Happy networking!
