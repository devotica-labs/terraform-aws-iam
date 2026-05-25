# Plan-only unit tests — no AWS credentials required.

provider "aws" {
  region                      = "ap-south-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock"
}

variables {
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
    cross-account = {
      trust_type       = "aws"
      trust_principals = ["arn:aws:iam::111122223333:root"]
      require_mfa      = true
    }
  }
  tags = { Environment = "unit-test" }
}

run "role_counts" {
  command = plan
  assert {
    condition     = length(aws_iam_role.this) == 3
    error_message = "Expected 3 roles to be planned."
  }
}

run "instance_profile_only_for_ec2" {
  command = plan
  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "Expected exactly 1 instance profile (only the ec2-app role opts in)."
  }
}

run "managed_policy_attachment_planned" {
  command = plan
  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 1
    error_message = "Expected 1 managed policy attachment (lambda-exec → AWSLambdaBasicExecutionRole)."
  }
}

run "name_prefix_applied" {
  command = plan
  variables {
    name_prefix = "devotica-test-"
  }
  assert {
    condition     = aws_iam_role.this["lambda-exec"].name == "devotica-test-lambda-exec"
    error_message = "name_prefix must be applied to the role name."
  }
}

run "password_policy_disabled_by_default" {
  command = plan
  assert {
    condition     = length(aws_iam_account_password_policy.this) == 0
    error_message = "Password policy must not be planned when manage_account_password_policy = false."
  }
}

run "password_policy_enabled" {
  command = plan
  variables {
    manage_account_password_policy = true
  }
  assert {
    condition     = length(aws_iam_account_password_policy.this) == 1
    error_message = "Password policy must be planned when manage_account_password_policy = true."
  }
}

run "account_alias_unmanaged_when_empty" {
  command = plan
  assert {
    condition     = length(aws_iam_account_alias.this) == 0
    error_message = "Account alias must not be planned when account_alias = \"\"."
  }
}

run "account_alias_managed_when_set" {
  command = plan
  variables {
    account_alias = "devotica-unit-test"
  }
  assert {
    condition     = length(aws_iam_account_alias.this) == 1
    error_message = "Account alias must be planned when account_alias is non-empty."
  }
}

run "access_analyzer_disabled_by_default" {
  command = plan
  assert {
    condition     = length(aws_accessanalyzer_analyzer.this) == 0
    error_message = "Access Analyzer must not be planned when disabled."
  }
}

run "access_analyzer_enabled" {
  command = plan
  variables {
    enable_iam_access_analyzer = true
  }
  assert {
    condition     = length(aws_accessanalyzer_analyzer.this) == 1
    error_message = "Access Analyzer must be planned when enabled."
  }
}

run "no_roles_is_valid" {
  command = plan
  variables {
    roles = {}
  }
  assert {
    condition     = length(aws_iam_role.this) == 0
    error_message = "Empty roles map must produce zero roles (account-baseline-only stacks must validate)."
  }
}
