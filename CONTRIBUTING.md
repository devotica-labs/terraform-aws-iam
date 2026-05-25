# Contributing

## Setup

```bash
brew install terraform tflint tfsec gitleaks pre-commit terraform-docs
pre-commit install
```

## Running tests locally

```bash
terraform init -backend=false
terraform test -filter=tests/unit.tftest.hcl
terraform test -filter=tests/contract.tftest.hcl
```

## Commit message format

We use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Semver bump |
|---|---|
| `feat:` | minor |
| `fix:`, `docs:`, `chore:` | patch |
| `feat!:` or `BREAKING CHANGE:` footer | major |

## Branch protection

`main` requires all CI checks green + one non-author review.
No direct pushes.
