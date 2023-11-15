################################################################
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Licensed Materials - Property of IBM
#
# ©Copyright IBM Corp. 2020
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################
variable "target" { default = "powervc" } 

variable "cluster_domain" {
  default = "example.com"
}
variable "cluster_id" {
  default = "test-ocp"
}

variable "dns_forwarders" {
  default = "9.9.9.9"
}

variable "gateway_ip" {}
variable "cidr" {}
#variable "allocation_pools" {}

variable "install_type" {}
variable "assisted_url" {}
variable "assisted_token" {}
variable "assisted_ocp_version" {}
variable "assisted_rhcos_version" {}

variable "bastion_vip" {}
variable "bastion_ip" {}
variable "rhel_username" {}
variable "private_key" {}
variable "ssh_agent" {}
variable "connection_timeout" {}
variable "jump_host" { default = "" }

variable "bastion_internal_vip" { default = "" }
variable "bastion_external_vip" { default = "" }
variable "bastion_public_ip" { default = [] }

variable "bootstrap_ip" {}
variable "master_ips" {}
variable "worker_ips" {}

variable "bootstrap_mac" {}
variable "master_macs" {}
variable "worker_macs" {}

variable "master_ids" { default = [] }
variable "worker_ids" { default = [] }

variable "openshift_client_tarball" {}
variable "openshift_install_tarball" {}
variable "openshift_rhcos_iso" {}
variable "openshift_rhcos_kernel" {}
variable "openshift_rhcos_initramfs" {}
variable "openshift_rhcos_rootfs" {}

variable "enable_local_registry" {}
variable "local_registry_image" {}
variable "ocp_release_tag" {}
variable "ocp_release_name" {}

variable "ansible_extra_options" {}

variable "public_key" {}
variable "pull_secret" {}

######################################


variable "release_image_override" {}
variable "fips_compliant" {}

variable "private_network_mtu" {}

variable "storage_type" {}
variable "log_level" {}

variable "rhcos_pre_kernel_options" {}
variable "rhcos_kernel_options" {}

variable "sysctl_tuned_options" {}
variable "sysctl_options" {}
variable "match_array" {}
variable "chrony_config" { default = true }
variable "chrony_config_servers" {}

variable "setup_squid_proxy" { default = false }
variable "proxy" {}

variable "cni_network_provider" {}
variable "cluster_network_cidr" {}
variable "cluster_network_hostprefix" {}
variable "service_network" {}

variable "luks_compliant" { default = false }
variable "luks_config" {}
variable "luks_filesystem_device" {}
variable "luks_format" {}
variable "luks_wipe_filesystem" {}
variable "luks_device" {}
variable "luks_label" {}
variable "luks_options" {}
variable "luks_wipe_volume" {}
variable "luks_name" {}

variable "setup_snat" { default = false }

variable "node_labels" {}

variable "public_cidr" {}

variable "bastion_count" {}
variable "bootstrap_count" {}
variable "master_count" {}
variable "worker_count" {}
