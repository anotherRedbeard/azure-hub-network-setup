# Contributing to Azure Hub Network Setup

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists in [GitHub Issues](https://github.com/anotherRedbeard/azure-hub-network-setup/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (Azure region, subscription type, etc.)

### Suggesting Enhancements

For feature requests or enhancements:

1. Open an issue with the `enhancement` label
2. Describe the feature and its benefits
3. Provide examples of how it would be used
4. Consider implementation approach

### Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/anotherRedbeard/azure-hub-network-setup.git
   cd azure-hub-network-setup
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the coding standards below
   - Update documentation as needed
   - Test your changes thoroughly

4. **Validate Bicep templates**
   ```bash
   ./validate-deployment.sh
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Provide clear description of changes
   - Reference any related issues
   - Include testing evidence

## Coding Standards

### Bicep Templates

- Use consistent naming conventions (lowercase with hyphens)
- Add descriptions to all parameters
- Include appropriate tags
- Document module dependencies
- Use latest API versions when possible

Example parameter:
```bicep
@description('Virtual Network name')
@minLength(1)
@maxLength(64)
param vnetName string
```

### Naming Conventions

Follow Azure naming best practices:

| Resource | Pattern | Example |
|----------|---------|---------|
| Resource Group | `rg-{purpose}-{env}` | `rg-hub-network-dev` |
| Virtual Network | `vnet-{purpose}-{env}` | `vnet-hub-dev` |
| Subnet | `snet-{purpose}` | `snet-dnsresolver-inbound` |
| VPN Gateway | `vpngw-{purpose}-{env}` | `vpngw-hub-dev` |
| Public IP | `pip-{resource}` | `pip-vpngw-hub-dev` |
| DNS Resolver | `dnspr-{purpose}-{env}` | `dnspr-hub-dev` |

### Parameter Files

- Keep environment-specific values in parameter files
- Don't commit secrets or sensitive data
- Use consistent structure across environments
- Document non-obvious parameter choices

### Documentation

- Update README.md for major changes
- Keep examples up to date
- Use markdown formatting consistently
- Include command examples with expected output

### GitHub Actions Workflows

- Use latest action versions
- Add comments for complex logic
- Handle errors appropriately
- Provide clear step names

## Testing

### Before Submitting

1. **Validate Bicep templates**
   ```bash
   az bicep build --file infra/bicep/main.bicep
   az bicep build --file infra/bicep/modules/vnet.bicep
   az bicep build --file infra/bicep/modules/vpn-gateway.bicep
   az bicep build --file infra/bicep/modules/dns-resolver.bicep
   ```

2. **Run validation script**
   ```bash
   ./validate-deployment.sh
   ```

3. **Test what-if deployment**
   ```bash
   az deployment sub what-if \
     --location eastus \
     --template-file infra/bicep/main.bicep \
     --parameters infra/parameters/dev.parameters.json
   ```

4. **Test actual deployment (if applicable)**
   - Deploy to a test subscription
   - Verify all resources are created
   - Test VPN connectivity
   - Clean up resources after testing

### Test Checklist

- [ ] Bicep templates build without errors
- [ ] Parameter files are valid JSON
- [ ] What-if shows expected changes
- [ ] Deployment completes successfully
- [ ] All outputs are correct
- [ ] Documentation is updated
- [ ] No secrets are committed

## Project Structure

```
azure-hub-network-setup/
├── .github/
│   └── workflows/           # GitHub Actions workflows
├── infra/
│   ├── bicep/
│   │   ├── main.bicep      # Main orchestrator
│   │   └── modules/        # Reusable modules
│   └── parameters/         # Environment-specific parameters
├── DEPLOYMENT-EXAMPLES.md  # Usage examples
├── QUICK-START.md          # Getting started guide
├── WORKFLOW.md             # Workflow documentation
├── README.md               # Main documentation
└── validate-deployment.sh  # Local validation script
```

## Development Workflow

1. **Design Phase**
   - Discuss major changes in an issue first
   - Get feedback on approach
   - Consider impact on existing users

2. **Implementation Phase**
   - Write clean, documented code
   - Follow existing patterns
   - Test incrementally

3. **Review Phase**
   - Self-review your changes
   - Ensure all tests pass
   - Update documentation

4. **Merge Phase**
   - Address review feedback
   - Squash commits if requested
   - Celebrate! 🎉

## Code Review Process

Pull requests will be reviewed for:

1. **Functionality**
   - Does it work as intended?
   - Are edge cases handled?
   - Are there any bugs?

2. **Code Quality**
   - Is it readable and maintainable?
   - Are there better approaches?
   - Is it well-documented?

3. **Testing**
   - Has it been tested?
   - Are there test cases?
   - Can reviewers reproduce results?

4. **Documentation**
   - Is documentation updated?
   - Are examples clear?
   - Is it accurate?

## Areas for Contribution

We welcome contributions in these areas:

### Infrastructure

- [ ] Add Azure Bastion module
- [ ] Add Azure Firewall module
- [ ] Add Network Security Groups
- [ ] Add Route Tables
- [ ] Add Application Gateway
- [ ] Add Load Balancer

### Automation

- [ ] Add Terraform version
- [ ] Add Pulumi version
- [ ] Add ARM template version
- [ ] Add cost estimation script
- [ ] Add drift detection

### Documentation

- [ ] Add architecture diagrams
- [ ] Add video tutorials
- [ ] Add troubleshooting guides
- [ ] Translate to other languages
- [ ] Add more examples

### Testing

- [ ] Add Pester tests
- [ ] Add integration tests
- [ ] Add security scanning
- [ ] Add compliance checks

### CI/CD

- [ ] Add automated testing
- [ ] Add security scanning
- [ ] Add cost analysis
- [ ] Add notifications
- [ ] Add rollback capability

## Getting Help

- Open an issue for questions
- Tag issues with `question` label
- Check existing documentation first
- Be specific about your environment

## Recognition

Contributors will be:
- Listed in pull request
- Acknowledged in release notes
- Added to contributors list

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Thank You!

Your contributions help make this project better for everyone. We appreciate your time and effort! 🙏
