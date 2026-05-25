# terraform-aws-iam

[![CI](https://github.com/devotica-labs/terraform-aws-iam/actions/workflows/ci.yml/badge.svg)](https://github.com/devotica-labs/terraform-aws-iam/actions/workflows/ci.yml)
[![Release](https://github.com/devotica-labs/terraform-aws-iam/actions/workflows/release.yml/badge.svg)](https://github.com/devotica-labs/terraform-aws-iam/actions/workflows/release.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Production-grade AWS IAM module with a unified role surface for service
execution roles (Lambda/EC2/ECS/EKS) and cross-account assume roles, plus an
optional account-level baseline (password policy, alias, Access Analyzer).

This module follows the Devotica module shape: Apache-2.0 licensed, validated
inputs, plan-only unit + contract tests, terraform-docs auto-update, central
reusable CI from `devotica-labs/terraform-shared-config`, and signed releases
with CycloneDX SBOMs.

## Scope

| Surface | Covered |
|---|---|
| Service execution roles (Lambda, EC2, ECS, EKS) | ✅ |
| Cross-account assume roles (MFA + ExternalId) | ✅ |
| EC2 instance profiles | ✅ (opt-in per role) |
| Inline + managed policy attachments | ✅ |
| Permissions boundaries | ✅ |
| Account password policy (CIS v3.0 §1.5–1.11) | ✅ |
| Account alias | ✅ |
| IAM Access Analyzer (CIS 1.20) | ✅ |
| IAM users / groups | ❌ (use AWS SSO / IAM Identity Center) |
| GitHub OIDC provider + workload identity | ❌ (planned for v0.2) |
| SCPs / Organization policies | ❌ (out of scope; use a dedicated org module) |

## Quick start

```hcl
module "iam" {
  source  = "devotica-labs/iam/aws"
  version = "~> 1.0"

  roles = {
    lambda-exec = {
      trust_type          = "service"
      trust_principals    = ["lambda.amazonaws.com"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
    }
  }

  tags = {
    Environment = "production"
    Project     = "platform"
    Owner       = "cloud-team@example.com"
    CostCenter  = "PLATFORM"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/your-org/your-infra"
  }
}
```

See [`examples/complete`](examples/complete/main.tf) for the full surface
(EC2 instance profile, ECS task role, cross-account admin with MFA,
third-party auditor with ExternalId, password policy, alias, Access Analyzer).

## Defaults that matter

- **Password policy**: 14-char min, mixed case + numbers + symbols, 90-day
  max age, 24-password history. Aligned with CIS v3.0 and RBI cyber-security
  guidance.
- **max_session_duration**: 3600 (1h). Override per-role up to 43200 (12h).
- **path**: `/`. Override per-role for organisational scoping
  (`/service-roles/`, `/cross-account/`, etc.).
- **Tags**: every taggable resource gets `ManagedBy = "terraform"` and
  `Module = "terraform-aws-iam"` merged with `var.tags`.

## Governance

- CI runs the central reusable workflow from `devotica-labs/terraform-shared-config`:
  fmt, validate, tflint, tfsec, gitleaks, terraform-docs, conftest against
  `devotica-labs/terraform-policies`, terraform test, checkov, examples build.
- Releases are cut by `release-please` on Conventional Commits. Each release
  is keyless-signed via cosign and ships a CycloneDX SBOM.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will inject the inputs/outputs/resources tables here on the next CI run -->
<!-- END_TF_DOCS -->

## License

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
