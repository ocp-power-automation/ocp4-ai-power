# Install Openshift cluster for PowerVM

This playbook can be used to install Openshift cluster to PowerVM, it supports 4 types of installation:
1. Agent-based Installation
2. Assisted-service based installation
3. Single node cluster installation without bootstrap
4. Normal OCP cluster installation
   
## Prepare the bastion

The bastion's `SELINUX` has to be set to `permissive` mode, otherwise ansible playbook will fail, to do it open file `/etc/selinux/config` and set `SELINUX=permissive`.

Create the ssh key which will be used for OCP installation:
```shell
ssh-keygen -t rsa -b 2048 -N '' -C 'BASTION-SSHKEY' -f ~/.ssh/id_rsa"
```

Download the pull-secret from [try.openshift.com](https://cloud.redhat.com/openshift/install/pre-release) and save it as `~/.openshift/pull-secret` on the bastion.

Setup the password-less access to HMC:
```shell
# <hscroot> is the userid, <hmc_ip> is the HMC IP address
ssh <hscroot>@<hmc_ip>
# <~/.ssh/id_rsa.pub> is the content of ~/.ssh/id_rsa.pub
mkauthkeys -a "<~/.ssh/id_rsa.pub>"
```

The `bastion` need to install required packages to be able to run this playbook, it requires to run as root. All OCP nodes need to have the static IP assigned with internet access.

Install base with this script, it can be run on CentOS or Redhat Linux:
```shell
cat > setup-bastion.sh << EOF
    DISTRO=$(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om || echo "")
	OS_VERSION=$(lsb_release -rs 2>/dev/null || cat /etc/*release 2>/dev/null | grep "VERSION_ID" | awk -F "=" '{print $2}' | sed 's/"*//g' || echo "")
	if [[ "$DISTRO" != *CentOS* ]]; then # for Redhat
		if [[ $(cat /etc/redhat-release | sed 's/[^0-9.]*//g') > 8.5 ]]; then
	  		sudo subscription-manager repos --enable codeready-builder-for-rhel-9-ppc64le-rpms
	  		sudo yum install -y ansible-core
		else
	  	  	sudo subscription-manager repos --enable ansible-2.9-for-rhel-8-ppc64le-rpms
	  	  	sudo yum install -y ansible
		fi
	else # for centos
		if [[ $OS_VERSION != "8"* ]]; then
			sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
			sudo yum install -y ansible-core
		else
			sudo yum install -y epel-release epel-next-release
			sudo yum config-manager --set-enabled powertools
			sudo yum install -y ansible
		fi
	fi
	
	# install additional modules for ansible
	sudo ansible-galaxy collection install community.crypto --upgrade
	sudo ansible-galaxy collection install community.general --upgrade
	sudo ansible-galaxy collection install ansible.posix --upgrade
	sudo ansible-galaxy collection install kubernetes.core --upgrade

    # install all required packages
    sudo yum install -y wget jq git net-tools vim tar unzip python3 python3-pip python3-jmespath coreos-installer grub2-tools-extra bind-utils 

    # install files for PXE
	sudo grub2-mknetdir --net-directory=/var/lib/tftpboot
EOF
chmod +x setup-bastion.sh
./setup-bastion.sh
```

Clone this playbook from `github.com` to bastion:
```shell
git clone https://github.com/cs-zhang/ocp4-ai-powervm.git
```

## Create the vars.yaml
Go `ocp4-ai-powervm` and create new vars.file from the `example-vars.yaml`
```shell
cd ocp4-ai-powervm
cp example-vars.yaml vars.yaml
```
Modify the `vars.yaml` based on the [doc](docs/vars-doc.md).

>Note: Before modify the `vars.yaml`, you have to create all required VMs(LPARs), then you will have LPAR the network info to update the `vars.yaml`.

## Deploy the Cluster
Now we have every thing set, and we can run the playbook:
```shell
cd ocp4-ai-powervm
ansible-playbook -e @vars.yaml playbooks/main.yaml
```





