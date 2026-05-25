output "role_arns" {
  description = "Map of role key → ARN."
  value       = module.iam.role_arns
}

output "instance_profile_arns" {
  description = "Map of role key → instance profile ARN."
  value       = module.iam.instance_profile_arns
}

output "access_analyzer_arn" {
  description = "IAM Access Analyzer ARN."
  value       = module.iam.access_analyzer_arn
}
