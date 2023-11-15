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

locals {
  bastion_count = lookup(var.bastion, "count", 1)
}

data "ibm_pi_catalog_images" "catalog_images" {
  pi_cloud_instance_id = var.service_instance_id
}
data "ibm_pi_images" "project_images" {
  pi_cloud_instance_id = var.service_instance_id
}

locals {
  catalog_bastion_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == var.rhel_image_name]
  project_bastion_image = [for x in data.ibm_pi_images.project_images.image_info : x if x.name == var.rhel_image_name]
  invalid_bastion_image = length(local.project_bastion_image) == 0 && length(local.catalog_bastion_image) == 0
  # If invalid then use name to fail in ibm_pi_instance resource; else if not found in project then import using ibm_pi_image; else use the bastion image id
  bastion_image_id = (
    local.invalid_bastion_image ? var.rhel_image_name : (
      length(local.project_bastion_image) == 0 ? ibm_pi_image.bastion[0].image_id : local.project_bastion_image[0].id
    )
  )
  # If invalid then use hardcoded value; else if project image pool is not empty use catalog image pool; else if project image pool is empty use catalog image pool; else use project image pool
  bastion_storage_pool = (
    local.invalid_bastion_image ? "Tier3-Flash-1" : (
      length(local.project_bastion_image) == 0 ? local.catalog_bastion_image[0].storage_pool : (
        local.project_bastion_image[0].storage_pool == "" ? local.catalog_bastion_image[0].storage_pool : local.project_bastion_image[0].storage_pool
      )
    )
  )
}

# Copy image from catalog if not in the project and present in catalog
resource "ibm_pi_image" "bastion" {
  count                = length(local.project_bastion_image) == 0 && length(local.catalog_bastion_image) == 1 ? 1 : 0
  pi_image_name        = var.rhel_image_name
  pi_image_id          = local.catalog_bastion_image[0].image_id
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_network" "network" {
  pi_network_name      = var.network_name
  pi_cloud_instance_id = var.service_instance_id
}

resource "ibm_pi_network" "public_network" {
  pi_network_name      = "${var.name_prefix}pub-net"
  pi_cloud_instance_id = var.service_instance_id
  pi_network_type      = "pub-vlan"
  pi_dns               = var.network_dns
}

resource "ibm_pi_key" "key" {
  pi_cloud_instance_id = var.service_instance_id
  pi_key_name          = "${var.name_prefix}keypair"
  pi_ssh_key           = var.public_key
}

resource "ibm_pi_volume" "volume" {
  count = var.storage_type == "nfs" ? 1 : 0

  pi_volume_size       = var.volume_size
  pi_volume_name       = "${var.name_prefix}${var.storage_type}-volume"
  pi_volume_pool       = local.bastion_storage_pool
  pi_volume_shareable  = var.volume_shareable
  pi_cloud_instance_id = var.service_instance_id
}

resource "ibm_pi_instance" "bastion" {
  count = local.bastion_count

  pi_memory            = var.bastion["memory"]
  pi_processors        = var.bastion["processors"]
  pi_instance_name     = "${var.name_prefix}bastion-${count.index}"
  pi_proc_type         = var.processor_type
  pi_image_id          = local.bastion_image_id
  pi_key_pair_name     = ibm_pi_key.key.name
  pi_sys_type          = var.system_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = var.bastion_health_status
  pi_volume_ids        = var.storage_type == "nfs" ? ibm_pi_volume.volume.*.volume_id : null
  pi_storage_pool      = local.bastion_storage_pool

  pi_network {
    network_id = ibm_pi_network.public_network.network_id
  }
  pi_network {
    network_id = data.ibm_pi_network.network.id
  }
}

data "ibm_pi_instance_ip" "bastion_ip" {
  count      = local.bastion_count
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion[count.index].pi_instance_name
  pi_network_name      = data.ibm_pi_network.network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_instance_ip" "bastion_public_ip" {
  count      = local.bastion_count
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion[count.index].pi_instance_name
  pi_network_name      = ibm_pi_network.public_network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

resource "ibm_pi_network_port" "bastion_vip" {
  count      = local.bastion_count > 1 ? 1 : 0
  depends_on = [ibm_pi_instance.bastion]

  pi_network_name      = data.ibm_pi_network.network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

resource "ibm_pi_network_port" "bastion_internal_vip" {
  count      = local.bastion_count > 1 ? 1 : 0
  depends_on = [ibm_pi_instance.bastion]

  pi_network_name      = ibm_pi_network.public_network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}
