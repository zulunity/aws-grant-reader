#!/bin/bash
export TRUSTED_ACCOUNT_ID=${1}
echo "========== Script to create a bucket that will preserve the state of a Reader Role for the TRUSTED_ACCOUNT_ID: $TRUSTED_ACCOUNT_ID ========"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity  | jq -r .Account)"
# Create a Bucket Name with the account and region
BUCKET="zulunity-remote-state-$AWS_ACCOUNT_ID-$AWS_REGION-$RANDOM"
# Create Bucket for remote storage
if [ "$AWS_REGION" == "us-east-1" ]; then
    aws s3api create-bucket \
        --bucket $BUCKET \
        --region $AWS_REGION
else
    aws s3api create-bucket \
        --bucket $BUCKET \
        --region $AWS_REGION \
        --create-bucket-configuration LocationConstraint=$AWS_REGION
fi
# Wait 33
sleep 33
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
# Install yum-utils
sudo yum install -y yum-utils
# Use yum-config-manager to add the official HashiCorp Linux repository.
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
# Install terraform 
sudo yum -y install terraform
# Clone aws-reader-role
git clone https://github.com/zulunity/aws-reader-role.git
# Enter into the repo 
cd aws-reader-role
# Terraform 
echo -en 'terraform {\n  backend "s3" {}\n}' > backend.tf
export TF_VAR_account_id="$TRUSTED_ACCOUNT_ID"
export TF_VAR_description="Role grating acces from $AWS_ACCOUNT_ID to $TRUSTED_ACCOUNT_ID as reader"
terraform init \
    -backend-config="bucket=$BUCKET" \
    -backend-config="key=state" \
    -backend-config="region=$AWS_REGION"
terraform apply -auto-approve
