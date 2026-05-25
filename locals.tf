locals {
  common_tags = merge(
    { ManagedBy = "terraform", Module = "terraform-aws-iam" },
    var.tags
  )

  # Effective role name = prefix + key
  role_names = {
    for k, _ in var.roles : k => "${var.name_prefix}${k}"
  }

  # Subset of roles that ask for an EC2 instance profile
  instance_profile_roles = {
    for k, r in var.roles : k => r if r.create_instance_profile
  }

  # Flattened list of (role_key, policy_arn) pairs for managed-policy
  # attachments. Stable keys "${role_key}::${policy_arn}" survive ordering
  # changes in the policy lists.
  role_policy_attachments = merge([
    for k, r in var.roles : {
      for arn in r.managed_policy_arns :
      "${k}::${arn}" => { role_key = k, policy_arn = arn }
    }
  ]...)

  # Flattened list of (role_key, policy_name) pairs for inline policies.
  role_inline_policies = merge([
    for k, r in var.roles : {
      for pname, pdoc in r.inline_policies :
      "${k}::${pname}" => { role_key = k, policy_name = pname, policy_document = pdoc }
    }
  ]...)
}
