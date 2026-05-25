# ---------------------------------------------------------------------------
# IAM roles — service execution roles (Lambda/EC2/ECS/EKS) AND
# cross-account assume roles, unified under a single var.roles map.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  for_each = var.roles

  name                 = local.role_names[each.key]
  path                 = each.value.path
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = each.value.max_session_duration
  permissions_boundary = each.value.permissions_boundary_arn

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Managed policy attachments — one resource per (role, policy) pair,
# keyed for stability under reorder.
# ---------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.role_policy_attachments

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

# ---------------------------------------------------------------------------
# Inline policies — one resource per (role, policy_name) pair.
# ---------------------------------------------------------------------------

resource "aws_iam_role_policy" "inline" {
  for_each = local.role_inline_policies

  name   = each.value.policy_name
  role   = aws_iam_role.this[each.value.role_key].id
  policy = each.value.policy_document
}

# ---------------------------------------------------------------------------
# EC2 instance profiles — only for roles that opted in.
# ---------------------------------------------------------------------------

resource "aws_iam_instance_profile" "this" {
  for_each = local.instance_profile_roles

  name = local.role_names[each.key]
  role = aws_iam_role.this[each.key].name
  path = each.value.path

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Account password policy — CIS-hardened defaults.
# Note: there is exactly one password policy per account.
# ---------------------------------------------------------------------------

resource "aws_iam_account_password_policy" "this" {
  count = var.manage_account_password_policy ? 1 : 0

  minimum_password_length        = var.password_policy.minimum_password_length
  require_lowercase_characters   = var.password_policy.require_lowercase_characters
  require_uppercase_characters   = var.password_policy.require_uppercase_characters
  require_numbers                = var.password_policy.require_numbers
  require_symbols                = var.password_policy.require_symbols
  allow_users_to_change_password = var.password_policy.allow_users_to_change_password
  max_password_age               = var.password_policy.max_password_age
  password_reuse_prevention      = var.password_policy.password_reuse_prevention
  hard_expiry                    = var.password_policy.hard_expiry
}

# ---------------------------------------------------------------------------
# Account alias — globally unique across AWS.
# ---------------------------------------------------------------------------

resource "aws_iam_account_alias" "this" {
  count = var.account_alias != "" ? 1 : 0

  account_alias = var.account_alias
}

# ---------------------------------------------------------------------------
# IAM Access Analyzer — CIS 1.20.
# ---------------------------------------------------------------------------

resource "aws_accessanalyzer_analyzer" "this" {
  count = var.enable_iam_access_analyzer ? 1 : 0

  analyzer_name = var.access_analyzer_name
  type          = var.access_analyzer_type

  tags = local.common_tags
}
