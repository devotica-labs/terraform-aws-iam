# Integration tests — apply + assert + destroy.
# Requires real AWS credentials. Triggered via workflow_dispatch on integration.yml.
# Run manually: terraform test -filter=tests/integration.tftest.hcl

provider "aws" {
  region = "ap-south-1"
}

variables {
  name_prefix = "integ-test-"
  roles = {
    lambda-exec = {
      trust_type       = "service"
      trust_principals = ["lambda.amazonaws.com"]
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
      ]
    }
    ec2-app = {
      trust_type              = "service"
      trust_principals        = ["ec2.amazonaws.com"]
      create_instance_profile = true
    }
  }
  tags = { Environment = "integration-test", Ephemeral = "true" }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_iam_role.this["lambda-exec"].arn != ""
    error_message = "Lambda role was not created."
  }
  assert {
    condition     = aws_iam_role.this["ec2-app"].arn != ""
    error_message = "EC2 role was not created."
  }
  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "Instance profile must be created for the EC2 role."
  }
  assert {
    condition     = aws_iam_role.this["lambda-exec"].name == "integ-test-lambda-exec"
    error_message = "name_prefix must be applied to the role name."
  }
}
