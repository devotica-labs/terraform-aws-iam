# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Inline policy used by the EC2 role below — narrow read-only S3 access.
data "aws_iam_policy_document" "s3_audit_logs_read" {
  statement {
    sid       = "ReadAuditLogsBucket"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::devotica-audit-logs", "arn:aws:s3:::devotica-audit-logs/*"]
  }
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/iam/aws"
#   version = "~> 1.0"

module "iam" {
  source = "../.."

  name_prefix = "devotica-prod-"

  roles = {
    # --- Lambda execution role ---
    lambda-exec = {
      trust_type       = "service"
      trust_principals = ["lambda.amazonaws.com"]
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
        "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
      ]
      description = "Lambda execution role (VPC-attached)."
    }

    # --- EC2 instance role with instance profile ---
    ec2-app = {
      trust_type              = "service"
      trust_principals        = ["ec2.amazonaws.com"]
      create_instance_profile = true
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
      inline_policies = {
        s3-audit-read = data.aws_iam_policy_document.s3_audit_logs_read.json
      }
      description = "EC2 app instance role — SSM + read-only audit log bucket."
    }

    # --- ECS task role ---
    ecs-task = {
      trust_type       = "service"
      trust_principals = ["ecs-tasks.amazonaws.com"]
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
      ]
      description = "ECS task execution role."
    }

    # --- Cross-account admin role (MFA-gated) ---
    cross-account-admin = {
      trust_type           = "aws"
      trust_principals     = ["arn:aws:iam::111122223333:root"]
      require_mfa          = true
      max_session_duration = 3600
      managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      description          = "Assumable by management-account admins with MFA."
    }

    # --- Third-party auditor role (ExternalId + read-only) ---
    auditor-readonly = {
      trust_type           = "aws"
      trust_principals     = ["arn:aws:iam::999988887777:role/auditor"]
      external_id          = "devotica-audit-2026"
      max_session_duration = 3600
      managed_policy_arns  = ["arn:aws:iam::aws:policy/SecurityAudit"]
      description          = "Third-party security auditor — ExternalId-locked."
    }
  }

  # --- Account baseline ---
  manage_account_password_policy = true
  password_policy = {
    minimum_password_length   = 14
    max_password_age          = 90
    password_reuse_prevention = 24
  }

  account_alias = "devotica-prod"

  enable_iam_access_analyzer = true
  access_analyzer_name       = "devotica-prod-analyzer"
  access_analyzer_type       = "ACCOUNT"

  tags = {
    Environment = "production"
    Project     = "platform"
    Owner       = "cloud-team@devotica.com"
    CostCenter  = "PLATFORM"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-iam"
  }
}
