# Private DNS resolution between Google Cloud and AWS

This repository provides an example of how to resolve DNS names provided by a Route 53 private hosted zone on AWS from a Google Cloud VM. The whole communication flow is kept private using private networking and a VPN tunnel between both cloud providers.

This repository is based on https://github.com/GoogleCloudPlatform/gcp-to-aws-ha-vpn-terraform-module.

> **IMPORTANT:** This repository makes no effort to secure the endpoints and network infrastructure other than by deploying a VPN tunnel. Security groups and firewall rules are deliberately configured to allow all traffic for the sake of simplicity. In a real production environment, take extra care to ensure that these network and security resources are configured appropriately to allow only the intended traffic.

## How to run

```
# Initialize the Terraform modules and providers.
terraform init

# Deploy the stack. You will be asked to provide parameter details such as the regions.
terraform apply

# Execute the test.
terraform output -raw test_command | bash
```

# How to tear down

```
# Just destroy the deployed resources.
terraform destroy
```
