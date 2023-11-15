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

resource "openstack_compute_keypair_v2" "key-pair" {
  count      = var.create_keypair
  name       = var.keypair_name
  public_key = var.public_key
}

resource "random_id" "label" {
  count       = var.scg_id == "" ? 0 : 1
  byte_length = "2"
}

resource "openstack_compute_flavor_v2" "bastion_scg" {
  count        = var.scg_id == "" ? 0 : 1
  name         = "${var.bastion["instance_type"]}-${random_id.label[0].hex}-scg"
  region       = data.openstack_compute_flavor_v2.bastion.region
  ram          = data.openstack_compute_flavor_v2.bastion.ram
  vcpus        = data.openstack_compute_flavor_v2.bastion.vcpus
  disk         = data.openstack_compute_flavor_v2.bastion.disk
  swap         = data.openstack_compute_flavor_v2.bastion.swap
  rx_tx_factor = data.openstack_compute_flavor_v2.bastion.rx_tx_factor
  is_public    = data.openstack_compute_flavor_v2.bastion.is_public
  extra_specs  = merge(data.openstack_compute_flavor_v2.bastion.extra_specs, { "powervm:storage_connectivity_group" : var.scg_id })
}

data "openstack_compute_flavor_v2" "bastion" {
  name = var.bastion["instance_type"]
}

resource "openstack_compute_instance_v2" "bastion" {
  count = local.bastion_count

  name      = "${var.cluster_id}-bastion-${count.index}"
  image_id  = var.bastion["image_id"]
  flavor_id = var.scg_id == "" ? data.openstack_compute_flavor_v2.bastion.id : openstack_compute_flavor_v2.bastion_scg[0].id
  key_pair  = openstack_compute_keypair_v2.key-pair.0.name
  network {
    port = var.bastion_port_ids[count.index]
  }
  availability_zone = lookup(var.bastion, "availability_zone", var.openstack_availability_zone)
}

resource "openstack_blockstorage_volume_v3" "storage_volume" {
  count = var.storage_type == "nfs" ? 1 : 0

  name        = "${var.cluster_id}-${var.storage_type}-storage-vol"
  size        = var.volume_size
  volume_type = var.volume_storage_template
}

resource "openstack_compute_volume_attach_v2" "storage_v_attach" {
  #depends_on = [null_resource.bastion_init]
  count      = var.storage_type == "nfs" ? 1 : 0

  volume_id   = openstack_blockstorage_volume_v3.storage_volume[count.index].id
  instance_id = openstack_compute_instance_v2.bastion[count.index].id
}


