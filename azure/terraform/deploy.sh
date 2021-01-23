# Log into Azure
az login --use-device-code

# Initialize Terraform
terraform init

# Deploy Terraform infrastructure
terraform plan -out="main" -var 'admin_password=Password1234!'
terraform apply "main"

# Destroy Terraform infrastructure
# terraform destroy -auto-approve -var 'admin_password=Password1234!'
