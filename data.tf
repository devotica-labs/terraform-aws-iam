# Data sources used by main.tf.
# Kept minimal so tflint + terraform plan stay fast on offline runs.

# Per-role trust policy document. The for_each + dynamic blocks below
# render the right Principal block ("Service" vs "AWS") and optionally
# add MFA and ExternalId conditions for cross-account trust.
data "aws_iam_policy_document" "trust" {
  for_each = var.roles

  statement {
    sid     = "AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = each.value.trust_type == "service" ? "Service" : "AWS"
      identifiers = each.value.trust_principals
    }

    dynamic "condition" {
      for_each = each.value.trust_type == "aws" && each.value.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }

    dynamic "condition" {
      for_each = each.value.trust_type == "aws" && each.value.external_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [each.value.external_id]
      }
    }
  }
}
