#!/bin/bash
export TRUSTED_ACCOUNT_ID=${1}
echo "========== Script to create a bucket that will preserve the state of a Reader Role for the TRUSTED_ACCOUNT_ID: $TRUSTED_ACCOUNT_ID ========"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity  | jq -r .Account)"
# Create a Bucket Name with the account and region and a random value
RANDOM_VALUE=$RANDOM
BUCKET="zulunity-remote-state-$AWS_ACCOUNT_ID-$AWS_REGION-$RANDOM_VALUE"
# Create Bucket for remote storage
aws s3api create-bucket \
    --bucket $BUCKET \
    --region $AWS_REGION
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
# Store info on zulu-store
zulu_store_data(){
cat <<EOF
{
    "fields": {
        "account": {
            "stringValue": "$AWS_ACCOUNT_ID"
        },
        "bucket": {
            "stringValue": "$BUCKET"
        },
        "region": {
            "stringValue": "$AWS_REGION"
        },
        "role": {
            "stringValue": "arn:aws:iam::$AWS_ACCOUNT_ID:role/zulunity-reader"
        }
    }
}
EOF
}
curl -L -X POST -H 'Content-Type: application/json' \
    "https://firestore.googleapis.com/v1/projects/zulu-store/databases/(default)/documents/aws?documentId=$AWS_ACCOUNT_ID$RANDOM_VALUE" \
    -d "$(zulu_store_data)"
    