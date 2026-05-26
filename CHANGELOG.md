# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## 0.1.0 (2026-05-25)


### Features

* initial terraform-aws-iam module ([b06f676](https://github.com/devotica-labs/terraform-aws-iam/commit/b06f676b8a9326fc5a82668acc36869e9df56df3))

## [Unreleased]

### Added
- Initial module scaffold.
- Unified `var.roles` map for service execution roles (Lambda/EC2/ECS/EKS)
  and cross-account assume roles (with MFA + ExternalId conditions).
- Optional EC2 instance profile creation per role (`create_instance_profile`).
- Account baseline: IAM password policy (CIS-aligned defaults), account alias,
  IAM Access Analyzer.
- `examples/basic` (Lambda role) and `examples/complete` (full surface).
- `tests/unit.tftest.hcl` and `tests/contract.tftest.hcl` (plan-only).
