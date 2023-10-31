#!/bin/bash
export TRUSTED_ACCOUNT_ID=${1}
echo "========== Script to create a bucket that will preserve the state of a Reader Role for the TRUSTED_ACCOUNT_ID: $TRUSTED_ACCOUNT_ID ========"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity  | jq -r .Account)"
# Create a Bucket Name with the account and region and a random value
RANDOM_VALUE=$RANDOM
BUCKET="zulunity-remote-state-$AWS_ACCOUNT_ID-$AWS_REGION-$RANDOM_VALUE"
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
## Asking for required packages
if [ -z `which tofu` ]
then
    # Install tofu
    wget https://github.com/opentofu/opentofu/releases/download/v1.6.0-alpha3/tofu_1.6.0-alpha3_linux_amd64.zip
    unzip tofu_1.6.0-alpha3_linux_amd64.zip
    chmod +x tofu
    sudo mv tofu /usr/local/bin/tofu

fi
if [ -d "./aws-reader-role" ];
then
  rm -rf aws-reader-role
  git clone https://github.com/zulunity/aws-reader-role.git
else
  git clone https://github.com/zulunity/aws-reader-role.git
fi

# Enter into the repo 
cd aws-reader-role
# Terraform 
echo -en 'terraform {\n  backend "s3" {}\n}' > backend.tf
export TF_VAR_account_id="$TRUSTED_ACCOUNT_ID"
export TF_VAR_description="Role grating acces from $AWS_ACCOUNT_ID to $TRUSTED_ACCOUNT_ID as reader"
tofu init \
    -backend-config="bucket=$BUCKET" \
    -backend-config="key=reader-role" \
    -backend-config="region=$AWS_REGION"
tofu apply -auto-approve
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
    
