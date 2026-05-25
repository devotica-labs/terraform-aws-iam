# ---------------------------------------------------------------------------
# Core identity
# ---------------------------------------------------------------------------

variable "name_prefix" {
  description = "Optional string prepended to every role name (e.g. \"devotica-prod-\"). Useful for multi-tenant accounts. Leave empty for no prefix."
  type        = string
  default     = ""
  validation {
    condition     = length(var.name_prefix) <= 32
    error_message = "name_prefix must be 0–32 characters."
  }
}

# ---------------------------------------------------------------------------
# Roles — unified surface for service roles AND cross-account assume roles.
#
# trust_type controls the shape of the trust policy:
#
#   "service"  → Principal: { Service = trust_principals }
#                e.g. ["lambda.amazonaws.com"], ["ec2.amazonaws.com"],
#                     ["ecs-tasks.amazonaws.com"], ["eks.amazonaws.com"]
#
#   "aws"      → Principal: { AWS = trust_principals }
#                e.g. ["arn:aws:iam::111122223333:root"]   (entire account)
#                     ["arn:aws:iam::111122223333:role/admin"] (specific role)
#                Use this for cross-account assume roles. Pair with
#                require_mfa = true and/or external_id for breakglass /
#                third-party (auditor, vendor) trust.
#
# Each map key becomes the role name (with optional name_prefix applied).
# Use stable, descriptive keys — the key is part of the Terraform address
# and is hard to change later without resource recreation.
# ---------------------------------------------------------------------------

variable "roles" {
  description = "Map of IAM roles to create. Key = role name (after name_prefix). See module README for the per-role schema and examples for Lambda/EC2/ECS/EKS/cross-account."
  type = map(object({
    trust_type               = string
    trust_principals         = list(string)
    managed_policy_arns      = optional(list(string), [])
    inline_policies          = optional(map(string), {})
    path                     = optional(string, "/")
    max_session_duration     = optional(number, 3600)
    permissions_boundary_arn = optional(string)
    create_instance_profile  = optional(bool, false)
    require_mfa              = optional(bool, false)
    external_id              = optional(string)
    description              = optional(string, "")
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, r in var.roles : contains(["service", "aws"], r.trust_type)
    ])
    error_message = "Every role.trust_type must be either \"service\" or \"aws\"."
  }

  validation {
    condition = alltrue([
      for k, r in var.roles :
      r.max_session_duration >= 3600 && r.max_session_duration <= 43200
    ])
    error_message = "max_session_duration must be between 3600 (1h) and 43200 (12h) seconds."
  }

  validation {
    condition = alltrue([
      for k, r in var.roles :
      length(r.trust_principals) > 0
    ])
    error_message = "trust_principals must not be empty."
  }

  validation {
    condition = alltrue([
      for k, r in var.roles :
      r.trust_type == "aws" || (!r.require_mfa && r.external_id == null)
    ])
    error_message = "require_mfa and external_id are only valid when trust_type = \"aws\"."
  }

  validation {
    condition = alltrue([
      for k, r in var.roles :
      !r.create_instance_profile || (r.trust_type == "service" && contains(r.trust_principals, "ec2.amazonaws.com"))
    ])
    error_message = "create_instance_profile = true is only valid for roles trusting ec2.amazonaws.com."
  }
}

# ---------------------------------------------------------------------------
# Account password policy
#
# Defaults below are aligned with CIS AWS Foundations Benchmark v3.0 §1.5–1.11
# and RBI Cyber Security Framework for SCBs §III.2 (strong password controls).
# ---------------------------------------------------------------------------

variable "manage_account_password_policy" {
  description = "Manage the account-level IAM password policy. Only one password policy can exist per AWS account — set this on exactly one stack."
  type        = bool
  default     = false
}

variable "password_policy" {
  description = "Account password policy settings. Ignored when manage_account_password_policy = false."
  type = object({
    minimum_password_length        = optional(number, 14)
    require_lowercase_characters   = optional(bool, true)
    require_uppercase_characters   = optional(bool, true)
    require_numbers                = optional(bool, true)
    require_symbols                = optional(bool, true)
    allow_users_to_change_password = optional(bool, true)
    max_password_age               = optional(number, 90)
    password_reuse_prevention      = optional(number, 24)
    hard_expiry                    = optional(bool, false)
  })
  default = {}

  validation {
    condition     = var.password_policy.minimum_password_length >= 8 && var.password_policy.minimum_password_length <= 128
    error_message = "minimum_password_length must be between 8 and 128."
  }
  validation {
    condition     = var.password_policy.max_password_age >= 0 && var.password_policy.max_password_age <= 1095
    error_message = "max_password_age must be between 0 and 1095 days."
  }
  validation {
    condition     = var.password_policy.password_reuse_prevention >= 0 && var.password_policy.password_reuse_prevention <= 24
    error_message = "password_reuse_prevention must be between 0 and 24."
  }
}

# ---------------------------------------------------------------------------
# Account alias
# ---------------------------------------------------------------------------

variable "account_alias" {
  description = "Account alias (e.g. \"devotica-prod\"). Must be globally unique across AWS. Empty string (default) means do not manage."
  type        = string
  default     = ""
  validation {
    condition     = var.account_alias == "" || can(regex("^[a-z0-9][a-z0-9-]{2,62}$", var.account_alias))
    error_message = "account_alias must be 3–63 chars, lowercase alphanumeric/hyphen, and start with alphanumeric."
  }
}

# ---------------------------------------------------------------------------
# IAM Access Analyzer
# ---------------------------------------------------------------------------

variable "enable_iam_access_analyzer" {
  description = "Create an IAM Access Analyzer in this region. Required for CIS 1.20."
  type        = bool
  default     = false
}

variable "access_analyzer_name" {
  description = "Name for the IAM Access Analyzer. Ignored when enable_iam_access_analyzer = false."
  type        = string
  default     = "default-analyzer"
}

variable "access_analyzer_type" {
  description = "Analyzer scope. \"ACCOUNT\" inspects only this account; \"ORGANIZATION\" inspects every account in the AWS Organization (run from the org management account or a delegated administrator)."
  type        = string
  default     = "ACCOUNT"
  validation {
    condition     = contains(["ACCOUNT", "ORGANIZATION"], var.access_analyzer_type)
    error_message = "access_analyzer_type must be \"ACCOUNT\" or \"ORGANIZATION\"."
  }
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags merged onto every taggable resource."
  type        = map(string)
  default     = {}
}
