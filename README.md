# Private DNS resolution between Google Cloud and AWS

This repository provides an example of how to resolve DNS names provided by a Route 53 private hosted zone on AWS from a Google Cloud VM. The whole communication flow is kept private using private networking and a VPN tunnel between both cloud providers.

## How to run

```
# Initialize the Terraform modules and providers.
terraform init

# Deploy the stack. You will be asked to provide parameter details such as the regions.
terraform apply

# Execute the test.
terraform output -raw test_command | bash
```
