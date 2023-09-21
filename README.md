# aws-grant-reader
AWS Grant Reader Script

## Description

This script will create

An s3 bucket with versioning to store tf state created.

Create a Role with:
    ReadOnly Access
    Trust Relationship to the TRUSTED_ACCOUNT_ID

## Execution

- Log into your AWS CloudShell and execute (Replacing TRUSTED_ACCOUNT_ID with the account id)

```sh
bash -c "$(curl https://raw.githubusercontent.com/zulunity/aws-grant-reader/main/script.sh)" -s TRUSTED_ACCOUNT_ID
```

