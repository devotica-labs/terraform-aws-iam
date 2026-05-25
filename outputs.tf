output "role_arns" {
  description = "Map of role key → IAM role ARN."
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}

output "role_names" {
  description = "Map of role key → IAM role name (after name_prefix)."
  value       = { for k, r in aws_iam_role.this : k => r.name }
}

output "role_ids" {
  description = "Map of role key → IAM role ID (stable role identifier, e.g. for IAM Policy condition keys)."
  value       = { for k, r in aws_iam_role.this : k => r.unique_id }
}

output "instance_profile_arns" {
  description = "Map of role key → EC2 instance profile ARN. Only contains roles where create_instance_profile = true."
  value       = { for k, p in aws_iam_instance_profile.this : k => p.arn }
}

output "instance_profile_names" {
  description = "Map of role key → EC2 instance profile name. Only contains roles where create_instance_profile = true."
  value       = { for k, p in aws_iam_instance_profile.this : k => p.name }
}

output "account_password_policy_managed" {
  description = "Whether this module is managing the account-level password policy."
  value       = length(aws_iam_account_password_policy.this) > 0
}

output "account_alias" {
  description = "Account alias managed by this module. Empty string when unmanaged."
  value       = length(aws_iam_account_alias.this) > 0 ? aws_iam_account_alias.this[0].account_alias : ""
}

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer. Empty string when enable_iam_access_analyzer = false."
  value       = length(aws_accessanalyzer_analyzer.this) > 0 ? aws_accessanalyzer_analyzer.this[0].arn : ""
}

output "access_analyzer_id" {
  description = "ID of the IAM Access Analyzer. Empty string when enable_iam_access_analyzer = false."
  value       = length(aws_accessanalyzer_analyzer.this) > 0 ? aws_accessanalyzer_analyzer.this[0].id : ""
}
