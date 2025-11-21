# Terraform Provider Configuration for LocalStack
# This example shows how to configure the AWS provider to use LocalStack

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19.0"
    }
  }
}

# Provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # LocalStack endpoints
  endpoints {
    apigateway     = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    s3             = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

# Example S3 bucket resource
resource "aws_s3_bucket" "example" {
  bucket = "my-localstack-test-bucket"

  tags = {
    Name        = "LocalStack Test Bucket"
    Environment = "Dev"
  }
}

# Example DynamoDB table resource
resource "aws_dynamodb_table" "example" {
  name           = "my-localstack-test-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "LocalStack Test Table"
    Environment = "Dev"
  }
}
