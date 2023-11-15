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
locals {
  wildcard_dns   = ["nip.io", "xip.io", "sslip.io"]
  cluster_domain = contains(local.wildcard_dns, var.cluster_domain) ? "${var.bastion_vip != "" ? var.bastion_vip : var.bastion_ip[0]}.${var.cluster_domain}" : var.cluster_domain
}

resource "null_resource" "install" {

  connection {
    type         = "ssh"
    user         = var.rhel_username
    host         = var.bastion_ip[0]
    private_key  = var.private_key
    agent        = var.ssh_agent
    timeout      = "${var.connection_timeout}m"
    bastion_host = var.jump_host
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Running ocp install playbook...'",
      "cd ansible-bastion && ansible-playbook -i inventory -e @bastion_vars.yaml playbooks/step-4-monitor.yaml ${var.ansible_extra_options}"
    ]
  }
}


