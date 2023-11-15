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
  wildcard_dns   = ["nip.io", "xip.io", "sslip.io"]
  cluster_domain = contains(local.wildcard_dns, var.cluster_domain) ? "${var.bastion_vip != "" ? var.bastion_vip : var.bastion_ip[0]}.${var.cluster_domain}" : var.cluster_domain

  public_vrrp = {
    virtual_router_id = var.bastion_internal_vip == "" ? "" : split(".", var.bastion_internal_vip)[3]
    virtual_ipaddress = var.bastion_internal_vip
    password          = uuid()
  }

  # node_labels = {
  #   "topology.kubernetes.io/region"    = var.region
  #   "topology.kubernetes.io/zone"      = var.zone
  #   "node.kubernetes.io/instance-type" = var.system_type
  # }

  local_registry = {
    enable_local_registry = var.enable_local_registry
    registry_image        = var.local_registry_image
    ocp_release_repo      = "ocp4/openshift4"
    ocp_release_tag       = var.ocp_release_tag
    ocp_release_name      = var.ocp_release_name
  }

  proxy = {
    server    = lookup(var.proxy, "server", ""),
    port      = lookup(var.proxy, "port", "3128"),
    user_pass = lookup(var.proxy, "user", "") == "" ? "" : "${lookup(var.proxy, "user", "")}:${lookup(var.proxy, "password", "")}@"
  }

  local_registry_ocp_image = "registry.${var.cluster_id}.${local.cluster_domain}:5000/${local.local_registry.ocp_release_repo}:${var.ocp_release_tag}"

  bastion_vars = {
    cluster_domain        = local.cluster_domain
    cluster_id            = var.cluster_id
    bastion_ip            = var.bastion_vip != "" ? var.bastion_vip : var.bastion_ip[0]
    bastion_name          = var.bastion_vip != "" ? "${var.cluster_id}-bastion" : "${var.cluster_id}-bastion-0"
    bastion_vip           = var.bastion_vip
    isHA                  = var.bastion_vip != ""
    bastion_master_ip     = var.bastion_ip[0]
    bastion_backup_ip     = length(var.bastion_ip) > 1 ? slice(var.bastion_ip, 1, length(var.bastion_ip)) : []
    forwarders            = var.dns_forwarders
    gateway_ip            = var.gateway_ip
    subnet                = var.cidr
    private_network_mtu   = var.private_network_mtu
    netmask               = cidrnetmask(var.cidr)
    broadcast             = cidrhost(var.cidr, -1)
    # ipid                  = cidrhost(var.cidr, 0)
    # pool                  = var.allocation_pools[0]
    chrony_config         = var.chrony_config
    chrony_config_servers = var.chrony_config_servers

    target                = var.target
    install_type          = var.install_type
    assisted_url          = var.assisted_url
    assisted_token        = var.assisted_token
    assisted_ocp_version  = var.assisted_ocp_version
    assisted_rhcos_version= var.assisted_rhcos_version

    bootstrap_info = {
      ip   = var.bootstrap_ip,
      mac  = var.bootstrap_mac,
      name = "bootstrap"
    }
    master_info = [for ix in range(length(var.master_ips)) :
      {
        ip   = var.master_ips[ix],
        mac  = var.master_macs[ix],
        name = "master-${ix}"
      }
    ]
    worker_info = [for ix in range(length(var.worker_ips)) :
      {
        ip   = var.worker_ips[ix],
        mac  = var.worker_macs[ix],
        name = "worker-${ix}"
      }
    ]

    local_registry  = local.local_registry
    client_tarball  = var.openshift_client_tarball
    install_tarball = var.openshift_install_tarball
    rhcos_iso       = var.openshift_rhcos_iso
    rhcos_kernel    = var.openshift_rhcos_kernel
    rhcos_initramfs = var.openshift_rhcos_initramfs
    rhcos_rootfs    = var.openshift_rhcos_rootfs

    pull_secret                = var.pull_secret
    public_ssh_key             = var.public_key
    storage_type               = var.storage_type
    log_level                  = var.log_level
    release_image_override     = var.enable_local_registry ? local.local_registry_ocp_image : var.release_image_override
    enable_local_registry      = var.enable_local_registry
    fips_compliant             = var.fips_compliant
    node_connection_timeout    = 60 * var.connection_timeout
    rhcos_pre_kernel_options   = var.rhcos_pre_kernel_options
    rhcos_kernel_options       = var.rhcos_kernel_options
    sysctl_tuned_options       = var.sysctl_tuned_options
    sysctl_options             = var.sysctl_options
    match_array                = indent(2, var.match_array)
    setup_squid_proxy          = var.setup_squid_proxy
    squid_source_range         = var.cidr
    proxy_url                  = local.proxy.server == "" ? "" : "http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}"
    no_proxy                   = var.cidr
    #node_labels                = merge(local.node_labels, var.node_labels)
    node_labels                = var.node_labels
    chrony_config              = var.chrony_config
    chrony_config_servers      = var.chrony_config_servers
    chrony_allow_range         = var.cidr
    cni_network_provider       = var.cni_network_provider
    cluster_network_cidr       = var.cluster_network_cidr
    cluster_network_hostprefix = var.cluster_network_hostprefix
    service_network            = var.service_network
    # Set CNI network MTU to MTU - 100 for OVNKubernetes and MTU - 50 for OpenShiftSDN(default).
    # Add new conditions here when we have more network providers
    cni_network_mtu        = var.cni_network_provider == "OVNKubernetes" ? var.private_network_mtu - 100 : var.private_network_mtu - 50
    luks_compliant         = var.luks_compliant
    luks_config            = var.luks_config
    luks_filesystem_device = var.luks_filesystem_device
    luks_format            = var.luks_format
    luks_wipe_filesystem   = var.luks_wipe_filesystem
    luks_device            = var.luks_device
    luks_label             = var.luks_label
    luks_options           = var.luks_options
    luks_wipe_volume       = var.luks_wipe_volume
    luks_name              = var.luks_name
  }

  bastion_inventory = {
    rhel_username = var.rhel_username
    bastion_ip    = var.bastion_ip
  }
}

resource "null_resource" "config" {

  triggers = {
    bootstrap_count = var.bootstrap_ip == "" ? 0 : 1
    worker_count    = length(var.worker_ips)
    master_count    = length(var.master_ips)
  }

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
      "mkdir -p .openshift",
      "mkdir -p ansible-bastion"
      # "echo 'Cloning into ocp4-helpernode...'",
      # "git clone ${var.helpernode_repo} --quiet",
      # "cd ocp4-helpernode && git checkout ${var.helpernode_tag}"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/../ansible-bastion/"
    destination = "ansible-bastion"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/bastion_inventory", local.bastion_inventory)
    destination = "ansible-bastion/inventory"
  }

  provisioner "file" {
    content     = var.pull_secret
    destination = ".openshift/pull-secret"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/bastion_vars.yaml", local.bastion_vars)
    destination = "ansible-bastion/bastion_vars.yaml"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sed -i \"/^helper:.*/a \\ \\ networkifacename: $(ip r | grep \"${var.cidr} dev\" | awk '{print $3}')\" ansible-bastion/bastion_vars.yaml",
      "echo 'Running ansible-bastion playbook...'",
      "cd ansible-bastion && ansible-playbook  -i inventory -e @bastion_vars.yaml playbooks/setup-bastion.yaml ${var.ansible_extra_options} --become"
    ]
  }
}

resource "null_resource" "configure_public_vip" {
  count      = var.bastion_count > 1 ? var.bastion_count : 0
  depends_on = [null_resource.config]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/keepalived_vrrp_instance.tpl", local.public_vrrp)
    destination = "/tmp/keepalived_vrrp_instance"
  }
  provisioner "remote-exec" {
    inline = [
      # Set state=MASTER,priority=100 for first bastion and state=BACKUP,priority=90 for others.
      "sudo sed -i \"s/state <STATE>/state ${count.index == 0 ? "MASTER" : "BACKUP"}/\" /tmp/keepalived_vrrp_instance",
      "sudo sed -i \"s/priority <PRIORITY>/priority ${count.index == 0 ? "100" : "90"}/\" /tmp/keepalived_vrrp_instance",
      "sudo sed -i \"s/interface <INTERFACE>/interface $(ip r | grep ${var.public_cidr} | awk '{print $3}')/\" /tmp/keepalived_vrrp_instance",
      "sudo cat /tmp/keepalived_vrrp_instance >> /etc/keepalived/keepalived.conf",
      "sudo systemctl restart keepalived"
    ]
  }
}


resource "null_resource" "setup_snat" {
  count      = var.setup_snat ? var.bastion_count : 0
  depends_on = [null_resource.config]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [<<EOF

echo "Configuring SNAT (experimental)..."

sudo firewall-cmd --zone=public --add-masquerade --permanent
# Masquerade will enable ip forwarding automatically
sudo firewall-cmd --reload

EOF
    ]
  }
}

# resource "null_resource" "external_services" {
#   count      = var.use_ibm_cloud_services ? var.bastion_count : 0
#   depends_on = [null_resource.config, null_resource.setup_snat]

#   triggers = {
#     worker_count = length(var.worker_ips)
#   }

#   connection {
#     type        = "ssh"
#     user        = var.rhel_username
#     host        = var.bastion_public_ip[count.index]
#     private_key = var.private_key
#     agent       = var.ssh_agent
#     timeout     = "${var.connection_timeout}m"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo 'Stopping HAPROXY and DNS'",
#       "sudo systemctl stop haproxy.service && sudo systemctl stop named.service",
#       "sudo systemctl mask haproxy.service && sudo systemctl mask named.service",
#       "echo 'Changing DNS to external on bastion and dhcpd'",
#       # TODO: This is hardcoded to 9.9.9.9 to use external nameserver. Need to read from dns_forwarders.
#       # "sudo sed -i 's/nameserver 127.0.0.1/nameserver 9.9.9.9/g' /etc/resolv.conf",
#       # "sudo sed -i 's/option domain-name-servers.*/option domain-name-servers 9.9.9.9;/g' /etc/dhcp/dhcpd.conf",
#       # "echo 'Adding static route for VPC subnet in dhcpd'",
#       # "sudo sed -i '/option routers/i option static-routes ${cidrhost(var.vpc_cidr, 0)} ${var.gateway_ip};' /etc/dhcp/dhcpd.conf",
#       # "sudo systemctl restart dhcpd.service"
#     ]
#   }
# }

