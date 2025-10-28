# VPC module — README

Purpose
- Create a well-structured, multi-AZ VPC that is the single source of truth for networking in this framework.
- Provide the networking outputs consumed by other modules (EKS, Security).

What this module provides
- VPC with configurable CIDR.
- Public and private subnets across AZs (default configured in module call).
- Internet Gateway and NAT Gateway configuration.
- Route tables and associations.
- Outputs commonly used by other modules (vpc_id, private_subnet_ids, public_subnet_ids, availability_zones).

Why use this module
- Keeps networking concerns isolated and reusable across environments.
- Ensures consistent subnet layout and tagging for downstream modules.

Quick usage (root wiring)
```hcl
module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  identifier  = var.identifier
  common_tags = local.common_tags
}
```

Key inputs (high level)
- identifier — string; prefix for resource names.
- environment — string; environment name (dev/test/prod).
- cidr — string; VPC CIDR block (overridable).
- azs — list(string); which AZs to use (module defaults to a reasonable list).
- common_tags — map(string); tags applied to resources.

Key outputs (examples)
- vpc_id — the created VPC ID.
- private_subnet_ids — list of private subnet IDs (used by EKS).
- public_subnet_ids — list of public subnet IDs.
- availability_zones — list of AZs used.

Operational notes & recommendations
- Defaults are tuned for a two-AZ deployment for cost/complexity balance. Choose additional AZs in production as needed.
- If you intend to reuse an existing VPC, prefer wiring in `private_subnet_ids` and other values into downstream modules rather than changing this module.
- Monitor NAT gateway count and costs in non-production environments.

Troubleshooting
- If resources fail to create: validate AZ names and available IPs in the chosen CIDR blocks.
- If EKS mount targets fail: ensure subnets have sufficient IP space.
