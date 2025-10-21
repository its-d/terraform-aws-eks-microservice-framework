# Copyright 2025 Darian Lee
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.efs.id
}

output "efs_access_point_id" {
  description = "EFS access point ID for Grafana"
  value       = aws_efs_access_point.efs_access_point.id
}
