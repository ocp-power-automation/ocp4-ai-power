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
# ©Copyright IBM Corp. 2022
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################

provider "openstack" {
  user_name   = var.user_name
  password    = var.password
  tenant_name = var.tenant_name
  domain_name = var.domain_name
  auth_url    = var.auth_url
  insecure    = var.insecure
}

resource "random_id" "label" {
  count       = var.cluster_id == "" ? 1 : 0
  byte_length = "2" # Since we use the hex, the word lenght would double
  prefix      = "${var.cluster_id_prefix}-"
}

locals {
  # Generates cluster_id as combination of cluster_id_prefix + (random_id or user-defined cluster_id)
  cluster_id   = var.cluster_id == "" ? random_id.label[0].hex : (var.cluster_id_prefix == "" ? var.cluster_id : "${var.cluster_id_prefix}-${var.cluster_id}")
  storage_type = lookup(var.bastion, "count", 1) > 1 ? "none" : var.storage_type
}

module "bastion" {
  source = "./modules/1_bastion"

  cluster_id                      = local.cluster_id
  bastion                         = var.bastion
  bastion_port_ids                = module.network.bastion_port_ids
  scg_id                          = var.scg_id
  openstack_availability_zone     = var.openstack_availability_zone
  public_key                      = local.public_key
  create_keypair                  = local.create_keypair
  keypair_name                    = "${local.cluster_id}-keypair"
  storage_type                    = local.storage_type
  volume_size                     = var.volume_size
  volume_storage_template         = var.volume_storage_template
  scg_flavor_is_public            = var.scg_flavor_is_public
}

module "network" {
  source = "./modules/2_network"

  cluster_id              = local.cluster_id
  network_name            = var.network_name
  bastion                 = var.bastion
  bootstrap               = var.bootstrap
  master                  = var.master
  worker                  = var.worker
  network_type            = var.network_type
  sriov_vnic_failover_vfs = var.sriov_vnic_failover_vfs
  sriov_capacity          = var.sriov_capacity
}

module "setup_bastion" {
  depends_on = [module.bastion]
  source = "../tf-common/1_setup_bastion"

  cluster_id                      = local.cluster_id
  cluster_domain                  = var.cluster_domain
  bastion                         = var.bastion
  bastion_ip                      = module.bastion.bastion_ip
  rhel_username                   = var.rhel_username
  private_key                     = local.private_key
  public_key                      = local.public_key
  ssh_agent                       = var.ssh_agent
  connection_timeout              = var.connection_timeout
  jump_host                       = var.jump_host
  rhel_subscription_username      = var.rhel_subscription_username
  rhel_subscription_password      = var.rhel_subscription_password
  rhel_subscription_org           = var.rhel_subscription_org
  rhel_subscription_activationkey = var.rhel_subscription_activationkey
  ansible_repo_name               = var.ansible_repo_name
  setup_squid_proxy               = var.setup_squid_proxy
  proxy                           = var.proxy
  rhel_smt                        = var.rhel_smt
  storage_type                    = local.storage_type
  volume_size                     = var.volume_size
  volume_shareable                = false
}

module "config_ocp" {
  depends_on = [module.setup_bastion, module.network]
  source = "../tf-common/2_config_ocp"

  target                    = "powervc"
  cluster_domain            = var.cluster_domain
  cluster_id                = local.cluster_id
  dns_forwarders            = var.dns_forwarders
  gateway_ip                = module.network.gateway_ip
  cidr                      = module.network.cidr
  bastion_vip               = module.network.bastion_vip
  bastion_ip                = module.bastion.bastion_ip
  install_type              = var.install_type
  assisted_url              = var.assisted_url
  assisted_token            = var.assisted_token
  assisted_ocp_version      = var.assisted_ocp_version
  assisted_rhcos_version    = var.assisted_rhcos_version
  rhel_username             = var.rhel_username
  private_key               = local.private_key
  public_key                = local.public_key
  ssh_agent                 = var.ssh_agent
  connection_timeout        = var.connection_timeout
  jump_host                 = var.jump_host
  bootstrap_ip              = module.network.bootstrap_port_ip
  master_ips                = module.network.master_port_ips
  worker_ips                = module.network.worker_port_ips
  bootstrap_mac             = module.network.bootstrap_mac
  master_macs               = module.network.master_macs
  worker_macs               = module.network.worker_macs
  openshift_install_tarball = var.openshift_install_tarball
  openshift_client_tarball  = var.openshift_client_tarball
  openshift_rhcos_iso       = var.openshift_rhcos_iso
  openshift_rhcos_kernel    = var.openshift_rhcos_kernel
  openshift_rhcos_initramfs = var.openshift_rhcos_initramfs
  openshift_rhcos_rootfs    = var.openshift_rhcos_rootfs
  enable_local_registry     = var.enable_local_registry
  local_registry_image      = var.local_registry_image
  ocp_release_tag           = var.ocp_release_tag
  ocp_release_name          = var.ocp_release_name
  ansible_extra_options     = var.ansible_extra_options
  chrony_config             = var.chrony_config
  chrony_config_servers     = var.chrony_config_servers
  pull_secret               = file(coalesce(var.pull_secret_file, "/dev/null"))
  storage_type               = local.storage_type
  release_image_override     = var.release_image_override
  private_network_mtu        = var.private_network_mtu
  fips_compliant             = var.fips_compliant
  log_level                  = var.installer_log_level
  rhcos_pre_kernel_options   = var.rhcos_pre_kernel_options
  rhcos_kernel_options       = var.rhcos_kernel_options
  sysctl_tuned_options       = var.sysctl_tuned_options
  sysctl_options             = var.sysctl_options
  match_array                = var.match_array
  setup_squid_proxy          = var.setup_squid_proxy
  proxy                      = var.proxy

  node_labels                = var.node_labels
  cni_network_provider       = var.cni_network_provider
  cluster_network_cidr       = var.cluster_network_cidr
  cluster_network_hostprefix = var.cluster_network_hostprefix
  service_network            = var.service_network

  luks_compliant             = var.luks_compliant
  luks_config                = var.luks_config
  luks_filesystem_device     = var.luks_filesystem_device
  luks_format                = var.luks_format
  luks_wipe_filesystem       = var.luks_wipe_filesystem
  luks_device                = var.luks_device
  luks_label                 = var.luks_label
  luks_options               = var.luks_options
  luks_wipe_volume           = var.luks_wipe_volume
  luks_name                  = var.luks_name

  public_cidr                = var.cluster_network_cidr
  bastion_count              = lookup(var.bastion, "count", 1)
  bootstrap_count            = var.bootstrap["count"]
  master_count               = var.master["count"]
  worker_count               = var.worker["count"]
}


module "bootstrapnode" {
  source = "./modules/3_nodes/3_1_bootstrapnode"

  bastion_ip                  = module.network.bastion_vip == "" ? module.bastion.bastion_ip[0] : module.network.bastion_vip
  cluster_id                  = local.cluster_id
  bootstrap                   = var.bootstrap
  install_status              = module.config_ocp.install_status
  scg_id                      = var.scg_id
  openstack_availability_zone = var.openstack_availability_zone
  bootstrap_port_id           = module.network.bootstrap_port_id
  scg_flavor_is_public        = var.scg_flavor_is_public
}

module "masternodes" {
  source = "./modules/3_nodes/3_2_masternodes"

  bastion_ip                  = module.network.bastion_vip == "" ? module.bastion.bastion_ip[0] : module.network.bastion_vip
  cluster_id                  = local.cluster_id
  master                      = var.master
  install_status              = module.config_ocp.install_status
  scg_id                      = var.scg_id
  openstack_availability_zone = var.openstack_availability_zone
  master_port_ids             = module.network.master_port_ids
  mount_etcd_ramdisk          = var.mount_etcd_ramdisk
  scg_flavor_is_public        = var.scg_flavor_is_public
}

module "workernodes" {
  source = "./modules/3_nodes/3_3_workernodes"

  bastion_ip                  = module.network.bastion_vip == "" ? module.bastion.bastion_ip[0] : module.network.bastion_vip
  cluster_id                  = local.cluster_id
  worker                      = var.worker
  install_status              = module.config_ocp.install_status
  scg_id                      = var.scg_id
  openstack_availability_zone = var.openstack_availability_zone
  worker_port_ids             = module.network.worker_port_ids
  rhel_username               = var.rhel_username
  private_key                 = local.private_key
  ssh_agent                   = var.ssh_agent
  connection_timeout          = var.connection_timeout
  jump_host                   = var.jump_host
  scg_flavor_is_public        = var.scg_flavor_is_public
}

module "install" {
  depends_on = [module.bootstrapnode, module.masternodes, module.workernodes]
  source     = "../tf-common/3_install_ocp"

  cluster_domain        = var.cluster_domain
  cluster_id            = local.cluster_id
  bastion_vip           = module.network.bastion_vip
  bastion_ip            = module.bastion.bastion_ip
  rhel_username         = var.rhel_username
  private_key           = local.private_key
  ssh_agent             = var.ssh_agent
  connection_timeout    = var.connection_timeout
  jump_host             = var.jump_host
  ansible_extra_options = var.ansible_extra_options
}
