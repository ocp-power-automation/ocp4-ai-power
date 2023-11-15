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

  proxy = {
    server    = lookup(var.proxy, "server", ""),
    port      = lookup(var.proxy, "port", "3128"),
    user      = lookup(var.proxy, "user", ""),
    password  = lookup(var.proxy, "password", "")
    user_pass = lookup(var.proxy, "user", "") == "" ? "" : "${lookup(var.proxy, "user", "")}:${lookup(var.proxy, "password", "")}@"
    no_proxy  = "127.0.0.1,localhost,.${var.cluster_id}.${var.cluster_domain}"
  }
}

resource "null_resource" "bastion_init" {
  count = local.bastion_count

  connection {
    type         = "ssh"
    user         = var.rhel_username
    host         = var.bastion_ip[count.index]
    private_key  = var.private_key
    agent        = var.ssh_agent
    timeout      = "${var.connection_timeout}m"
    bastion_host = var.jump_host
  }
  provisioner "remote-exec" {
    inline = [
      "whoami"
    ]
  }
  provisioner "file" {
    content     = var.private_key
    destination = ".ssh/id_rsa"
  }
  provisioner "file" {
    content     = var.public_key
    destination = ".ssh/id_rsa.pub"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chmod 600 .ssh/id_rsa*",
      "sudo sed -i.bak -e 's/^ - set_hostname/# - set_hostname/' -e 's/^ - update_hostname/# - update_hostname/' /etc/cloud/cloud.cfg",
      "sudo hostnamectl set-hostname --static ${lower(var.cluster_id)}-bastion-${count.index}.${lower(var.cluster_id)}.${var.cluster_domain}",
      "echo 'HOSTNAME=${lower(var.cluster_id)}-bastion-${count.index}.${lower(var.cluster_id)}.${var.cluster_domain}' | sudo tee -a /etc/sysconfig/network > /dev/null",
      "sudo hostname -F /etc/hostname",
      "echo 'vm.max_map_count = 262144' | sudo tee --append /etc/sysctl.conf > /dev/null",
      "enforce=$(cat /etc/selinux/config | grep -i '^SELINUX=enforcing');if [[ $enforce != '' ]]; then sudo sed -i -e 's/^SELINUX=enforcing*/SELINUX=permissive/' /etc/selinux/config; echo 'set SELINUX to permissive'; fi",
      "sudo setenforce Permissive",
    ]
  }
}

resource "null_resource" "setup_proxy_info" {
  depends_on = [null_resource.bastion_init]
  count      = !var.setup_squid_proxy && local.proxy.server != "" ? local.bastion_count : 0
  connection {
    type         = "ssh"
    user         = var.rhel_username
    host         = var.bastion_ip[count.index]
    private_key  = var.private_key
    agent        = var.ssh_agent
    timeout      = "${var.connection_timeout}m"
    bastion_host = var.jump_host
  }
  # Setup proxy
  provisioner "remote-exec" {
    inline = [<<EOF

echo "Setting up proxy details..."

# System
set http_proxy="http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}"
set https_proxy="http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}"
set no_proxy="${local.proxy.no_proxy}"
echo "export http_proxy=\"http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}\"" | sudo tee /etc/profile.d/http_proxy.sh > /dev/null
echo "export https_proxy=\"http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}\"" | sudo tee -a /etc/profile.d/http_proxy.sh > /dev/null
echo "export no_proxy=\"${local.proxy.no_proxy}\"" | sudo tee -a /etc/profile.d/http_proxy.sh > /dev/null

# RHSM
sudo sed -i -e 's/^proxy_hostname =.*/proxy_hostname = ${local.proxy.server}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_port =.*/proxy_port = ${local.proxy.port}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_user =.*/proxy_user = ${local.proxy.user}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_password =.*/proxy_password = ${local.proxy.password}/' /etc/rhsm/rhsm.conf

# YUM/DNF
# Incase /etc/yum.conf is a symlink to /etc/dnf/dnf.conf we try to update the original file
yum_dnf_conf=$(readlink -f -q /etc/yum.conf)
sudo sed -i -e '/^proxy.*/d' $yum_dnf_conf
echo "proxy=http://${local.proxy.server}:${local.proxy.port}" | sudo tee -a $yum_dnf_conf > /dev/null
echo "proxy_username=${local.proxy.user}" | sudo tee -a $yum_dnf_conf > /dev/null
echo "proxy_password=${local.proxy.password}" | sudo tee -a $yum_dnf_conf > /dev/null

EOF
    ]
  }

}

resource "null_resource" "bastion_register" {
  count      = (var.rhel_subscription_username == "" || var.rhel_subscription_username == "<subscription-id>") && var.rhel_subscription_org == "" ? 0 : local.bastion_count
  depends_on = [null_resource.bastion_init, null_resource.setup_proxy_info]
  triggers = {
    bastion_ip         = var.bastion_ip[count.index]
    rhel_username      = var.rhel_username
    private_key        = var.private_key
    ssh_agent          = var.ssh_agent
    jump_host          = var.jump_host
    connection_timeout = var.connection_timeout
  }

  connection {
    type         = "ssh"
    user         = self.triggers.rhel_username
    host         = self.triggers.bastion_ip
    private_key  = self.triggers.private_key
    agent        = self.triggers.ssh_agent
    timeout      = "${self.triggers.connection_timeout}m"
    bastion_host = self.triggers.jump_host
  }

  provisioner "remote-exec" {
    inline = [<<EOF

# Give some more time to subscription-manager
sudo subscription-manager config --server.server_timeout=600
sudo subscription-manager clean
if [[ '${var.rhel_subscription_org}' == '' ]]; then
    sudo subscription-manager register --username='${var.rhel_subscription_username}' --password='${var.rhel_subscription_password}' --force
else
    sudo subscription-manager register --org='${var.rhel_subscription_org}' --activationkey='${var.rhel_subscription_activationkey}' --force
fi
sudo subscription-manager refresh
sudo subscription-manager attach --auto

EOF
    ]
  }
  # Delete Terraform files as contains sensitive data
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp/terraform_*"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type         = "ssh"
      user         = self.triggers.rhel_username
      host         = self.triggers.bastion_ip
      private_key  = self.triggers.private_key
      agent        = self.triggers.ssh_agent
      timeout      = "${self.triggers.connection_timeout}m"
      bastion_host = self.triggers.jump_host
    }

    when       = destroy
    on_failure = continue
    inline = [
      "sudo subscription-manager unregister",
      "sudo subscription-manager remove --all",
    ]
  }
}

resource "null_resource" "enable_repos" {
  count      = local.bastion_count
  depends_on = [null_resource.bastion_init, null_resource.setup_proxy_info, null_resource.bastion_register]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
DISTRO=$(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om || echo "")
OS_VERSION=$(lsb_release -rs 2>/dev/null || cat /etc/*release 2>/dev/null | grep "VERSION_ID" | awk -F "=" '{print $2}' | sed 's/"*//g' || echo "")
if [[ "$DISTRO" != *CentOS* ]]; then # for Redhat
	if [[ $OS_VERSION != "8"* ]]; then # for 9.x
  		sudo subscription-manager repos --enable codeready-builder-for-rhel-9-ppc64le-rpms
	else # for 8.x
		sudo subscription-manager repos --enable codeready-builder-for-rhel-8-ppc64le-rpms
	fi
	sudo yum install -y ansible-core
else # for centos
	if [[ $OS_VERSION != "8"* ]]; then  # for 9.x
		sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
		sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm
		sudo yum install -y ansible-core
	else  # for 8.x
		sudo yum install -y epel-release epel-next-release
		sudo yum config-manager --set-enabled powertools
		sudo yum install -y ansible
	fi
fi
EOF
    ]
  }
}

resource "null_resource" "bastion_packages" {
  count      = local.bastion_count
  depends_on = [null_resource.bastion_init, null_resource.setup_proxy_info, null_resource.bastion_register, null_resource.enable_repos]

  connection {
    type         = "ssh"
    user         = var.rhel_username
    host         = var.bastion_ip[count.index]
    private_key  = var.private_key
    agent        = var.ssh_agent
    timeout      = "${var.connection_timeout}m"
    bastion_host = var.jump_host
  }
  provisioner "remote-exec" {
    inline = [
      "#sudo yum update -y --skip-broken",
      "sudo yum install -y wget jq git net-tools vim tar unzip python3.11 python3.11-pip python3-jmespath grub2-tools-extra bind-utils", 
	    "sudo yum install -y coreos-installer openssl genisoimage nmstate-libs nmstate",
      "sudo pip3 install jmespath"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo ansible-galaxy collection install community.crypto",
      "sudo ansible-galaxy collection install ansible.posix",
      "sudo ansible-galaxy collection install kubernetes.core",
      "sudo ansible-galaxy collection install community.general"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl unmask NetworkManager",
      "sudo systemctl start NetworkManager",
      "for i in $(nmcli device | grep unmanaged | awk '{print $1}'); do echo NM_CONTROLLED=yes | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-$i; done",
      "sudo systemctl restart NetworkManager",
      "sudo systemctl enable NetworkManager"
    ]
  }
}

locals {
  disk_config = {
    volume_size = var.volume_size
    disk_name   = "disk/pv-storage-disk"
  }
  storage_path = "/export"
}

resource "null_resource" "setup_nfs_disk" {
  count      = var.storage_type == "nfs" ? 1 : 0

  connection {
    type         = "ssh"
    user         = var.rhel_username
    host         = var.bastion_ip[count.index]
    private_key  = var.private_key
    agent        = var.ssh_agent
    timeout      = "${var.connection_timeout}m"
    bastion_host = var.jump_host
  }
  provisioner "file" {
    content     = templatefile("${path.module}/templates/create_disk_link.sh", local.disk_config)
    destination = "/tmp/create_disk_link.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf mkdir ${local.storage_path}; sudo mkdir -p ${local.storage_path}; sudo chmod -R 755 ${local.storage_path}",
      "sudo chmod +x /tmp/create_disk_link.sh",
      # Fix for copying file from Windows OS having CR,
      "sudo sed -i 's/\r//g' /tmp/create_disk_link.sh",
      "sudo /tmp/create_disk_link.sh",
      "sudo mkfs.xfs /dev/${local.disk_config.disk_name}",
      "MY_DEV_UUID=$(sudo blkid -o export /dev/${local.disk_config.disk_name} | awk '/UUID/{ print }')",
      "echo \"$MY_DEV_UUID ${local.storage_path} xfs defaults 0 0\" | sudo tee -a /etc/fstab > /dev/null",
      "sudo mount ${local.storage_path}",
    ]
  }
}

# Workaround for unable to access RHEL 8.3 instance after reboot. TODO: Remove when permanently fixed.
# resource "null_resource" "rhel83_fix" {
#   count      = local.bastion_count
#   depends_on = [null_resource.bastion_packages, null_resource.setup_nfs_disk]

#   connection {
#     type        = "ssh"
#     user        = var.rhel_username
#     host        = var.bastion_ip[count.index]
#     private_key = var.private_key
#     agent       = var.ssh_agent
#     timeout     = "${var.connection_timeout}m"
#   }
#   provisioner "remote-exec" {
#     inline = [
#       "sudo yum remove cloud-init --noautoremove -y",
#     ]
#   }
# }