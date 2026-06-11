# Terraform Rule: Core Style

When writing or modifying Terraform/OpenTofu code, follow these rules.

## Principles

- Match the project's existing module structure. Do not introduce a new layout (e.g. `modules/`, `live/`, `stacks/`) unless asked.
- Pin every provider and every module by version. Floating versions break reproducibility.
- State is the source of truth for what exists. The code is the source of truth for what should exist. Drift between them is a bug to investigate, not a number to ignore.

## File layout

A typical module has these files at the root:

- `main.tf` — resources.
- `variables.tf` — input variables with `type`, `description`, and `default` (or `nullable = false` and no default for required).
- `outputs.tf` — outputs with `description`. Mark `sensitive = true` where appropriate.
- `versions.tf` — `terraform { required_version = "~> 1.x" }` block + `required_providers`.
- `README.md` (optional) — usage example.

Do not scatter resources across many `*.tf` files inside the same module unless the file count exceeds ~10 — small modules are easier to review whole.

## Naming

- Resource names lowercase_snake_case: `resource "aws_s3_bucket" "logs"` (not `logs-bucket`).
- Variables and outputs in lowercase_snake_case.
- Use prefixes when names could collide across providers: `aws_account_id`, not just `account_id`, when both AWS and GCP are in scope.

## Variables

- Every `variable` has `type` and `description`. Required variables have **no `default`**; let Terraform fail at plan time if missing.
- Use `validation` blocks for non-trivial input constraints:
  ```hcl
  variable "instance_type" {
    type = string
    description = "EC2 instance type"
    validation {
      condition = can(regex("^[a-z][1-9]\\.", var.instance_type))
      error_message = "instance_type must look like 'm5.large'."
    }
  }
  ```
- Mark variables containing secrets as `sensitive = true` so they don't appear in plan/apply output.

## Providers

- Pin in `versions.tf` with `required_providers`:
  ```hcl
  terraform {
    required_version = "~> 1.6"
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.50"
      }
    }
  }
  ```
- Do not configure provider `region`, `profile`, or credentials in the module itself. The root module / consuming code passes them.

## State

- Remote state only. Never commit `terraform.tfstate` or `.terraform/`.
- One state file per environment. Sharing state across `dev`/`stage`/`prod` is a foot-cannon.
- Enable state locking (DynamoDB for S3 backend, native locking for HCP/GCS).
- `terraform import` to bring existing resources under management; don't recreate them.

## Secrets

- Never put secrets in `.tfvars` files committed to git.
- Read from a secret manager at plan time: `data "aws_secretsmanager_secret_version" "x"` or `data "external"` for ad-hoc fetches.
- Mark output secrets `sensitive = true`.

## Modules

- Pin module versions when consuming from a registry: `source = "registry.terraform.io/foo/bar/aws"` `version = "~> 2.1"`.
- Pin module versions when consuming from git: `source = "git::https://github.com/foo/bar.git//modules/x?ref=v1.2.3"` (note the `?ref=` tag).
- Don't reach into other modules' resources via `module.x.resource.y.attribute` from outside the module — that's what outputs are for.

## Performance and safety

- `lifecycle { prevent_destroy = true }` on stateful resources (databases, persistent disks, anything you'd cry over).
- Use `create_before_destroy` for resources where replacement causes downtime.
- `terraform plan` before every apply. Review the diff. Never `--auto-approve` interactive applies in production.

## Formatting

- `terraform fmt -recursive` before commit.
- `tflint` and `terraform validate` in CI.
- Use `for_each` (not `count`) when iterating over a map or set — `count` is order-sensitive and causes destruction on reorder.

## Examples

### Good

```hcl
terraform {
  required_version = "~> 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.50" }
  }
}

variable "name" {
  type        = string
  description = "Bucket name suffix. Must be globally unique."
  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 30
    error_message = "name must be 3–30 characters."
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "myapp-logs-${var.name}"
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_arn" {
  value       = aws_s3_bucket.logs.arn
  description = "ARN of the logs bucket."
}
```

### Bad

```hcl
# Unpinned provider, no validation, secret in tfvars, count over a map:
provider "aws" {}

variable "name" { default = "test" }                      # silent default
variable "db_password" { default = "hunter2" }            # secret in code

resource "aws_s3_bucket" "logs" {
  bucket = "myapp-logs-${var.name}"
  count  = length(var.envs)                                # order-sensitive
}
```
