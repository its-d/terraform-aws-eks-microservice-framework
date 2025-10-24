## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.18.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_efs_access_point.efs_access_point](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_efs_file_system.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.efs_mount](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags | `map(string)` | `{}` | no |
| <a name="input_efs_security_group_id"></a> [efs\_security\_group\_id](#input\_efs\_security\_group\_id) | Security Group ID to associate with the EFS mount targets | `string` | n/a | yes |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Identifier for naming resources | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs where EFS mount targets will be created | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_efs_access_point_id"></a> [efs\_access\_point\_id](#output\_efs\_access\_point\_id) | EFS access point ID for Grafana |
| <a name="output_efs_file_system_id"></a> [efs\_file\_system\_id](#output\_efs\_file\_system\_id) | EFS file system ID |
| <a name="output_grafana_efs_ap_id"></a> [grafana\_efs\_ap\_id](#output\_grafana\_efs\_ap\_id) | Alias of the EFS access point ID for Grafana |
