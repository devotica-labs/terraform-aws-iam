# Contract tests — output surface is stable across minor + patch versions.
# Uses plan command — outputs are unknown at plan time so we check
# they are planned (not null) using length checks on known values.

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
    a = { trust_type = "service", trust_principals = ["lambda.amazonaws.com"] }
    b = { trust_type = "service", trust_principals = ["ec2.amazonaws.com"], create_instance_profile = true }
  }
}

# Contract: every role key gets a role planned with the matching name suffix
run "role_keys_stable" {
  command = plan
  assert {
    condition     = aws_iam_role.this["a"].name == "a"
    error_message = "Role name must equal the map key when name_prefix is empty."
  }
  assert {
    condition     = aws_iam_role.this["b"].name == "b"
    error_message = "Role name must equal the map key when name_prefix is empty."
  }
}

# Contract: instance profile is created exactly for roles that opt in
run "instance_profile_keying_stable" {
  command = plan
  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "Only the EC2 role opting into create_instance_profile should produce an instance profile."
  }
}

# Contract: password policy resource is absent when feature disabled
run "password_policy_guarded" {
  command = plan
  assert {
    condition     = length(aws_iam_account_password_policy.this) == 0
    error_message = "Password policy must be feature-flagged off by default."
  }
}

# Contract: access analyzer is absent when feature disabled
run "access_analyzer_guarded" {
  command = plan
  assert {
    condition     = length(aws_accessanalyzer_analyzer.this) == 0
    error_message = "Access Analyzer must be feature-flagged off by default."
  }
}

# Contract: account alias is absent when var.account_alias = ""
run "account_alias_guarded" {
  command = plan
  assert {
    condition     = length(aws_iam_account_alias.this) == 0
    error_message = "Account alias must be guarded by the empty-string sentinel."
  }
}
