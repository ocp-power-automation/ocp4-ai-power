# How to use vars.yaml

This page gives you an explanation of the variables found in the [vars.yaml](../example-vars.yaml) example given in this repo to help you formulate your own/edit the provided example.


## Disk to install RHCOS

In the first section, you'll see that it's asking for a disk

```
disk: /dev/sda
```

This needs to be set to the disk where you are installing RHCOS on the masters/workers. This will be set in the boot options for the `pxe server`.

**NOTE**: This is global and it will be the same for ALL masters and workers. You add `disk: /dev/sdb` to any master or worker node which uses different disk.


## Helper Section

This section sets the variables for the helpernode

```
helper:
  name: "helper"
  ipaddr: "192.168.7.77"
  networkifacename: "eth0"
```

This is how it breaks down

* `helper.name` - *REQUIRED*: This needs to be set to the hostname you want your helper to be (some people leave it as "helper" others change it to "bastion")
* `helper.ipaddr` - *REQUIRED* Set this to the current IP address of the helper. In case of high availability cluster, set this to the virtual IP address of the helpernodes. This is used to set up the `reverse dns definition`.
* `helper.networkifacename` - *OPTIONAL*: By default the playbook uses `{{ ansible_default_ipv4.interface }}` for the interface of the helper or helpernodes (In case of high availability). This option can be set to override the interface used for the helper or helpernodes (if, for example, you're on a dual homed network or your helper has more than one interface).

**NOTE**: The `helper.networkifacename` is the ACTUAL name of the interface, NOT the NetworkManager name (you should _NEVER_ need to set it to something like `System eth0`. Set it to what you see in `ip addr`)


## DNS Section

This section sets up your DNS server.

```
dns:
  domain: "example.com"
  clusterid: "ocp4"
  forwarder1: "8.8.8.8"
  forwarder2: "8.8.4.4"
```

Explanation of the DNS variables:

* `dns.domain` - This is what domain the installed DNS server will have. This needs to match what you will put for the `baseDomain` inside the `install-config.yaml` file.
* `dns.clusterid` - This is what your clusterid will be named and needs to match what you will for `metadata.name` inside the `install-config.yaml` file.
* `dns.forwarder1` - This will be set up as the DNS forwarder. This is usually one of the corporate (or "upstream") DNS servers.
* `dns.forwarder2` - This will be set up as the second DNS forwarder. This is usually one of the corporate (or "upstream") DNS servers.

The DNS server will be set up using `dns.clusterid` + `dns.domain` as the domain it's serving. In the above example, the helper will be setup to be the SOA for `ocp4.example.com`. The helper will also be setup as it's own DNS server.

**NOTE**: Although you _CAN_ use the helper as your dns server. It's best to have your DNS server delegate the `dns.clusterid` + `dns.domain` domain to the helper (i.e. Delegate `ocp4.example.com` to the helper)

## DHCP Section

This section sets up the DHCP server.

```
dhcp:
  router: "192.168.7.1"
  bcast: "192.168.7.255"
  netmask: "255.255.255.0"
  subnet: "192.168.7.0/24"
```

Explanation of the options you can set:

* `dhcp.router` - This is the default gateway of your network you're going to assign to the masters/workers
* `dhcp.bcast` - This is the broadcast address for your network
* `dhcp.netmask` - This is the netmask that gets assigned to your masters/workers
* `dhcp.subnet` - This is the subnet for the network

These variables are used to set up the dhcp config.

## Bootstrap Node Section
> **OPTIONAL** Not needed for SNO, assisted and agent-based installation.
 
This section defines the bootstrap node configuration

```
bootstrap:
  name: "bootstrap"
  ipaddr: "192.168.7.20"
  macaddr: "52:54:00:60:72:67"
  pvmcec: "Server-9800"
  pvmlpar: "pvm-bootstrap"
  disk: /dev/sda
```

The options are:

* `bootstrap.name` - The hostname (**__WITHOUT__** the fqdn) of the bootstrap node you want to set
* `bootstrap.ipaddr` - The IP address that you want set
* `bootstrap.macaddr` - The mac address for dhcp reservation
* `bootstrap.pvmcec` - The system name where the VM resident
* `bootstrap.pvmlpar` - The lpar name in system(Can be found in HMC, not name in PowerVC)
* `bootstrap.disk` -- Optional, the disk to install RHCOS if it is different from global definition.


## Master Node section

Similar to the bootstrap section; this sets up master node configuration. Please note that this is an array.

```
masters:
  - name: "master0"
    ipaddr: "192.168.7.21"
    macaddr: "52:54:00:e7:9d:67"
    pvmcec: Server-9080
    pvmlpar: pvm-master-0
    disk: /dev/sda
  - name: "master1"
    ipaddr: "192.168.7.22"
    macaddr: "52:54:00:80:16:23"
    pvmcec: Server-9080
    pvmlpar: pvm-master-1
    disk: /dev/sda
  - name: "master2"
    ipaddr: "192.168.7.23"
    macaddr: "52:54:00:d5:1c:39"
    pvmcec: Server-9080
    pvmlpar: pvm-master-2
    disk: /dev/sda
```

* `masters.name` - The hostname (**__WITHOUT__** the fqdn) of the master node you want to set (x of 3).
* `masters.ipaddr` - The IP address (x of 3) that you want set 
* `masters.macaddr` - The mac address for dhcp reservation
* `masters.pvmcec` - The system name where the VM resident
* `masters.pvmlpar` - The lpar name in system(Can be found in HMC, not name in PowerVC)
* `masters.disk` -- Optional, the disk to install RHCOS if it is different from global definition.
* 
**NOTE**: 3 Masters are MANDATORY for installation of OpenShift 4, but for SNO installation one master is required.

## Worker Node section

Similar to the master section; this sets up worker node configuration. Please note that this is an array.

> :rotating_light: This section is optional if you're installing a compact cluster or SNO

```
workers:
  - name: "worker0"
    ipaddr: "192.168.7.11"
    macaddr: "52:54:00:f4:26:a1"
    pvmcec: Server-9080
    pvmlpar: pvm-worker-0
    disk: /dev/sda
  - name: "worker1"
    ipaddr: "192.168.7.12"
    macaddr: "52:54:00:82:90:00"
    pvmcec: Server-9080
    pvmlpar: pvm-worker-1
    disk: /dev/sda
  - name: "worker2"
    ipaddr: "192.168.7.13"
    macaddr: "52:54:00:8e:10:34"
    pvmcec: Server-9080
    pvmlpar: pvm-worker-2
    disk: /dev/sda
```

* `workers.name` - The hostname (**__WITHOUT__** the fqdn) of the worker node you want to set
* `workers.ipaddr` - The IP address that you want set 
* `workers.macaddr` - The mac address for dhcp reservation
* `workers.pvmcec` - The system name where the VM resident
* `workers.pvmlpar` - The lpar name in system(Can be found in HMC, not name in PowerVC)
* `workers.disk` -- Optional, the disk to install RHCOS if it is different from global definition.

## other required sections

### HMC access
In order the playbook to access to HMC to net boot up the LPARs, we need to access to HMC with password-less access:
```
pvc_hmc: <hmc_user>@<hmc_ip>
```

### Installation type
This playbook supports 4 installation types:
1. agent -- agent based installing
2. assisted -- assisted-service based installation
3. sno -- SNO installation
4. normal -- normal OCP installation which requires bootstrap node(not working yet)
```
install_type: agent
```

For assisted-service installation following need to be defined:
```
assisted_url: "https://api.openshift.com/api/assisted-install/v2"
assisted_token: "eyJhbGciOiJIUzI1NiIs........."
assisted_ocp_version: "4.13"
assisted_rhcos_version: "4.13"
```
>Note: `assisted_token` can be found at your [RedHat account](https://cloud.redhat.com/openshift/install/), at the bottom of the page `OpenShift Cluster Manager API Token`.

## Extra sections

Below are example of "extra" features beyond the default built-in vars that you can manipulate.


### Specifying Artifacts

You can have the helper deploy specific artifacts for a paticular version of OCP. Or, the nightly builds of OpenShift 4 or even OKD. Adding the following to your `vars.yaml` file will pull in the corresponding artifacts.

```
# RHCOS server for OCP
rhcos_arch: "ppc64le"
rhcos_base_url: "https://mirror.openshift.com/pub/openshift-v4/{{ rhcos_arch }}/dependencies/rhcos"
# RHCOS server for OCP
rhcos_rhcos_base: "4.13"
rhcos_rhcos_tag: "latest"
#rhcos_iso: "{{ rhcos_base_url}}/{{ rhcos_rhcos_base }}/{{ rhcos_rhcos_tag }}/rhcos-live.{{ rhcos_arch }}.iso"
rhcos_rootfs: "{{ ocp_base_url}}/{{ ocp_rhcos_base }}/{{ ocp_rhcos_tag }}/rhcos-live-rootfs.{{ rhcos_arch }}.img"
rhcos_initramfs: "{{ ocp_base_url}}/{{ ocp_rhcos_base }}/{{ ocp_rhcos_tag }}/rhcos-live-initramfs.{{ rhcos_arch }}.img"
rhcos_kernel: "{{ ocp_base_url}}/{{ ocp_rhcos_base }}/{{ ocp_rhcos_tag }}/rhcos-live-kernel-{{ rhcos_arch }}"

# URL path to OCP clients download site
ocp_client_arch: "ppc64le"
ocp_base_url: "https://mirror.openshift.com/pub/openshift-v4/{{ ocp_client_arch }}/clients"
ocp_client_base: "ocp"
ocp_client_tag: "latest-4.13"
ocp_client: "{{ ocp_base_url}}/{{ ocp_client_base }}/{{ ocp_client_tag }}/openshift-client-linux.tar.gz"
ocp_installer: "{{ ocp_base_url}}/{{ ocp_client_base }}/{{ ocp_client_tag }}/openshift-install-linux.tar.gz"

```

### Download Artifacts
Some install types require to download RHCOS and client to setup PXE, like SNO and normal, but for Agent-based and assisted install, they don't need the RHCOS file downloaded, they will extract them from ISO.
```
force_ocp_download: false
```

### Public SSH Key

This playbook can use the SSH key at bastion's `~/.ssh/id_rsa.pub` 
```
public_ssh_key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```


### Pull Secret
The pull-secret is required to perform OCP installation, it can be obtained at bottom of the page of [try.openshift.com](https://cloud.redhat.com/openshift/install/)  - Download and save it as `~/.openshift/pull-secret` on the helper node.
```
pull_secret: '{{ lookup("file", "~/.openshift/pull-secret") | from_json | to_json }}'
```

### Working directory
The working directory is where all config files and generated files atr stored
```
workdir: "~/workdir-ocp4-{{ install_type }}
```

### Local Registry

**OPTIONAL**

In order to install a local registry on the helper node:
* A pullsecret obtained at [try.openshift.com](https://cloud.redhat.com/openshift/install/pre-release) - Download and save it as `~/.openshift/pull-secret` on the helper node.
* you'll need to add the following in your `vars.yaml` file

```
setup_registry:
  deploy: false
  autosync_registry: false
  registry_image: docker.io/ibmcom/registry-ppc64le:2.6.2.5
  local_repo: "ocp4/openshift4"
  product_repo: "openshift-release-dev"
  release_name: "ocp-release"
  release_tag: "4.14.0-ppc64le"
```

* `setup_registry.deploy` - Set this to true to enable registry installation.
* `setup_registry.autosync_registry` - Set this to true to enable mirroring of installation images.
* `setup_registry.registry_image` - This is the name of the image used for creating registry container.
* `setup_registry.local_repo` - This is the name of the repo in your registry.
* `setup_registry.product_repo` - Where the images are hosted in the product repo.
* `setup_registry.release_name` - This is the name of the image release.
* `setup_registry.release_tag` - The version of OpenShift you want to sync.

### Proxy setting

**OPTIONAL**

The playbook can use exist proxy to access public internet:
```
proxy_url: http://192.168.79.2:3128
no_proxy: 127.0.0.0/16
```

### OCP Customizations

**OPTIONAL**

These variables are defined to customization of the cluster after it has be installed successfully.
```
rhcos_kernel_options: []
sysctl_tuned_options: false
powervm_rmc: true
```
* `rhcos_kernel_options` - List of kernel options for RHCOS nodes eg: ["slub_max_order=0","loglevel=7"]
* `sysctl_tuned_options` - Set to true to apply sysctl options via tuned operator 
* `powervm_rmc` - Set to true to deploy RMC daemonset on Node with arch ppc64le 

