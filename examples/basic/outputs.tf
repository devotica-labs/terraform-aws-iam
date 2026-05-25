output "role_arns" {
  description = "Map of role key → ARN."
  value       = module.iam.role_arns
}
