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
# ©Copyright IBM Corp. 2023
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################

resource "ibm_pi_instance_action" "bootstrap_start" {
  count      = var.bootstrap_count == 0 ? 0 : 1

  pi_cloud_instance_id = var.service_instance_id
  pi_instance_id       = "${var.name_prefix}bootstrap"
  pi_action            = "start"
  pi_health_status     = "WARNING"
}

resource "ibm_pi_instance_action" "master_start" {
  depends_on = [ibm_pi_instance_action.bootstrap_start]
  count      = var.master_count

  pi_cloud_instance_id = var.service_instance_id
  pi_instance_id       = "${var.name_prefix}master-${count.index}"
  pi_action            = "start"
  pi_health_status     = "WARNING"
}

resource "ibm_pi_instance_action" "worker_start" {
  depends_on = [ibm_pi_instance_action.master_start]
  count      = var.worker_count

  pi_cloud_instance_id = var.service_instance_id
  pi_instance_id       = "${var.name_prefix}worker-${count.index}"
  pi_action            = "start"
  pi_health_status     = "WARNING"
}
