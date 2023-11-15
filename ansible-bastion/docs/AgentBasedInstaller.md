# Using OpenShift Agent-based Install for PowerVM

The latest OpenShift release 4.15 has added the Agent-based installation support for Power. Agent-based installation is a subcommand of the OpenShift Container Platform installer. It generates a bootable ISO image containing all of the information required to deploy an OpenShift Container Platform cluster, with an available release image. More details information can be found [here](https://docs.openshift.com/container-platform/4.13/installing/installing_with_agent_based_installer/preparing-to-install-with-agent-based-installer.html).


## Requirements for Agent-based Installer

To do the OCP HA installation, we need four VMs, one works as bastion and others as OCP control plane nodes, the minimum hardware requirements as show as below:

| VM   | vCPU  |  Memory  | Storage |
| :----|-----:|--------:|-------:|
| Bastion | 2   |  8GB    |  50 GB  |
| Master | 4   |  16GB   | 100GB   |
| Worker | 2 | 8GB  | 100GB |
| SNO  | 8 | 16GB | 120GB |

The `bastion` is used to setup required services, it requires to run as root. All OCP nodes need to have the static IP assigned with internet access.

## Bastion setup
The bastion's `SELINUX` has to be set to `permissive` mode, otherwise ansible playbook will fail, to do it open file `/etc/selinux/config` and set `SELINUX=permissive`.

We will use PXE for OCP installation, that requires the following services to be configured and run on `bastion`:
- DNS -- to define `api`, `api-int` and `*.apps` 
- DHCP -- to enable PXE and assign IP to OCP nodes
- HTTP -- to provide ignition and RHCOS rootfs image 
- TFTP -- to enable PXE
- HAPROXY -- to enable load balancer for OCP

We need to install `dnsmasq` to support DNS, DHCP and PXE, `httpd` for HTTP, `haproxy` for OCP load balancer, `coreos-installer` for ISO operation.

Here are some values used in sample configurations:
- 192.168.10.8 -- Bastion's IP
- 192.168.10.1 -- Network route or gateway
- agent.lab  -- OCP's domain name
- p9-ha -- OCP's cluster_id
- 192.168.10.x -- OCP node IPs


### Setup dnsmasq

Here is a sample configuration file for `/etc/dnsmasq.conf` with 3 masters:
```
#################################
# DNS
##################################
#domain-needed
# don't send bogus requests out on the internets
bogus-priv
# enable IPv6 Route Advertisements
enable-ra
bind-dynamic
no-hosts
#  have your simple hosts expanded to domain
expand-hosts


interface=env32
# set your domain for expand-hosts
domain=p9-ha.agent.lab
local=/p9-ha.agent.lab/
address=/apps.p9-ha.agent.lab/192.168.10.8
server=9.9.9.9

addn-hosts=/etc/dnsmasq.d/addnhosts


##################################
# DHCP
##################################
dhcp-ignore=tag:!known
dhcp-leasefile=/var/lib/dnsmasq/dnsmasq.leases

dhcp-range=192.168.10.242,static

dhcp-option=option:router,192.168.10.1
dhcp-option=option:netmask,255.255.255.0
dhcp-option=option:dns-server,192.168.10.8


dhcp-host=fa:1d:67:35:13:20,master-1,192.168.10.242,infinite
dhcp-host=fa:41:fb:ed:77:20,master-2,192.168.10.231,infinite
dhcp-host=fa:31:cd:db:a5:20,master-3,192.168.10.225,infinite


###############################
# PXE
###############################
enable-tftp
tftp-root=/var/lib/tftpboot
dhcp-boot=boot/grub2/powerpc-ieee1275/core.elf
```

and `/etc/dnsmasq.d/addnhosts` file:
```
192.168.10.8 api api-int
192.168.10.242 master-1
192.168.10.231 master-2
192.168.10.225 master-3
```

### PXE setup
To enable PXE for PowerVM, we need to install `grub2` with:
```shell
grub2-mknetdir --net-directory=/var/lib/tftpboot
```

Here is the sample `/var/lib/tftpboot/boot/grub2/grub.cfg`, the listen port for HTTPD is 8000:
```shell
default=0
fallback=1
timeout=1

if [ ${net_default_mac} == fa:1d:67:35:13:20 ]; then
default=0
fallback=1
timeout=1
menuentry "CoreOS (BIOS)" {
   echo "Loading kernel"
   linux "/rhcos/kernel" ip=dhcp rd.neednet=1 ignition.platform.id=metal ignition.firstboot coreos.live.rootfs_url=http://192.168.10.8:8000/install/rootfs.img ignition.config.url=http://192.168.10.8:8000/ignition/assisted.ign

   echo "Loading initrd"
   initrd  "/rhcos/initramfs.img"
}
fi

if [ ${net_default_mac} == fa:41:fb:ed:77:20 ]; then
default=0
fallback=1
timeout=1
menuentry "CoreOS (BIOS)" {
   echo "Loading kernel"
   linux "/rhcos/kernel" ip=dhcp rd.neednet=1 ignition.platform.id=metal ignition.firstboot coreos.live.rootfs_url=http://192.168.10.8:8000/install/rootfs.img ignition.config.url=http://192.168.10.8:8000/ignition/assisted.ign

   echo "Loading initrd"
   initrd  "/rhcos/initramfs.img"
}
fi

if [ ${net_default_mac} == fa:31:cd:db:a5:20 ]; then
default=0
fallback=1
timeout=1
menuentry "CoreOS (BIOS)" {
   echo "Loading kernel"
   linux "/rhcos/kernel" ip=dhcp rd.neednet=1 ignition.platform.id=metal ignition.firstboot coreos.live.rootfs_url=http://192.168.10.8:8000/install/rootfs.img ignition.config.url=http://192.168.10.8:8000/ignition/assisted.ign

   echo "Loading initrd"
   initrd  "/rhcos/initramfs.img"
}
fi
```

### Setup haproxy
Here is the configuration file `/etc/haproxy/haproxy.cfg` for haproxy:
```shell
#---------------------------------------------------------------------
# Example configuration for a possible web application.  See the
# full configuration options online.
#
#   http://haproxy.1wt.eu/download/1.4/doc/configuration.txt
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    #
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    #
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    tcp
    log                     global
    option                  httplog
    option                  dontlognull
    option                  http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          4h
    timeout server          4h
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

#---------------------------------------------------------------------

listen stats
    bind :9000
    mode http
    stats enable
    stats uri /
    monitor-uri /healthz

frontend openshift-api-server
    bind *:6443
    default_backend openshift-api-server
    option tcplog

backend openshift-api-server
    balance source
    server master-1 192.168.10.242:6443 check
    server master-2 192.168.10.231:6443 check
    server master-3 192.168.10.225:6443 check

frontend machine-config-server
    bind *:22623
    default_backend machine-config-server
    option tcplog

backend machine-config-server
    balance source
    server master-1 192.168.10.242:22623 check
    server master-2 192.168.10.231:22623 check
    server master-3 192.168.10.225:22623 check

frontend machine-config-server-day2
    bind *:22624
    default_backend machine-config-server-day2
    option tcplog

backend machine-config-server-day2
    balance source
    server master-1 192.168.10.242:22624 check
    server master-2 192.168.10.231:22624 check
    server master-3 192.168.10.225:22624 check

frontend ingress-http
    bind *:80
    default_backend ingress-http
    option tcplog

backend ingress-http
    balance source
    server master-1-http-router0 192.168.10.242:80 check
    server master-2-http-router1 192.168.10.231:80 check
    server master-3-http-router2 192.168.10.225:80 check

frontend ingress-https
    bind *:443
    default_backend ingress-https
    option tcplog

backend ingress-https
    balance source
    server master-1-https-router0 192.168.10.242:443 check
    server master-2-https-router1 192.168.10.231:443 check
    server master-3-https-router2 192.168.10.225:443 check

#---------------------------------------------------------------------

```

## Prepare Agent-based installation
To do the agent-based installation requires following steps:
1. Download the latest `openshift-install`
2. Create `install-config.yaml` and `agent-config.yaml`
3. Run `openshift-install` to create the ISO
4. Extract RHCOS files and ignition from ISO
5. Setup the PXE with these files
   
### Download `openshift-install`
Download the latest `openshift-install` from OpenShift mirror site for Power:
```shell
mkdir -p ~/agent-works
cd ~/ai-works
wget https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp-dev-preview/4.15.0-ec.0/openshift-install-linux.tar.gz
tar xzvf openshift-install-linux.tar.gz
```

### Create the `install-config.yaml` and `agent-config.yaml`
At the work directory `~/agent-works` to create two `.yaml` files. 
Here is the sample `install-config.yaml`:
```
apiVersion: v1
baseDomain: agent.lab
compute:
  architecture: ppc64le 
  hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  architecture: ppc64le
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: p9-ha 
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 192.168.10.0/24
  networkType: OVNKubernetes 
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '<pull_secret>' 
sshKey: |
  '<ssh_pub_key>' 
```
Note:
1. `<pull_secret>`  -- Specify your pull secret.
2. `<ssh_pub_key>`  -- Specify your SSH public key.

Here is the sample `agent-config.yaml`, it uses the DHCP for IP and network configuration:
```
apiVersion: v1alpha1
metadata:
  name: p9-ha
rendezvousIP: 192.168.10..242
hosts:
  - hostname: master-1
    role: master
    interfaces:
       - name: eth0
         macAddress: fa:1d:67:35:13:20
    networkConfig:
      interfaces:
        - name: eth0
          type: ethernet
          state: up
          mac-address: fa:1d:67:35:13:20
          ipv4:
            enabled: true
            address:
              - ip: 192.168.10..242
                prefix-length: 24
            dhcp: true
  - hostname: master-2
    role: master
    interfaces:
       - name: eth0
         macAddress: fa:41:fb:ed:77:20
    networkConfig:
      interfaces:
        - name: eth0
          type: ethernet
          state: up
          mac-address: fa:41:fb:ed:77:20
          ipv4:
            enabled: true
            address:
              - ip: 192.168.10..231
                prefix-length: 24
            dhcp: true
  - hostname: master-3
    role: master
    interfaces:
       - name: eth0
         macAddress: fa:31:cd:db:a5:20
    networkConfig:
      interfaces:
        - name: eth0
          type: ethernet
          state: up
          mac-address: fa:31:cd:db:a5:20
          ipv4:
            enabled: true
            address:
              - ip: 192.168.10..225
                prefix-length: 24
            dhcp: true
```
Note the `rendezvousIP` is the host which performs the bootstrapping process as well as running the assisted-service component.

### Create the bootable ISO
Now we can run `openshift-install` to create the `agent.iso`:
```shell
cd ~/agent-works
./openshift-install agent create image --log-level=info
```

### Setup PXE 
now we can extract the ignition file and PXE files fro the ISO and setup PXE:
```shell
cd ~/ai-works
# extract ignition file from ISO
coreos-installer iso ignition show agent.iso > agent.ign
coreos-installer iso extract pxe agent.iso 
# copy the ignition file to http's ignition directory
cp agent.ign /var/www/html/ignition/.
# copy rootfs.img to http's install directory
cp  agent-rootfs.img /var/www/html/install/rootfs.img
restorecon -vR /var/www/html || true
# copy PXE files to it's directory:
cp agent-vmlinuz /var/lib/tftpboot/rhcos/kernel
cp agent--initrd.img /var/lib/tftpboot/rhcos/initramfs.img
```

Now `bastion` has all required files and configurations to install OCP.

## Start installation
There two steps for agent-based installation:
1. Directly mount ISO to all LPARs and boot from ISO
2. Using PXE to boot LPARs from network
Here we just detail steps for using PXE installation.

### Network boot all nodes
To boot PowerVM with netboot, there are two ways to do it: using SMS interactively to select bootp or using `lpar_netboot`  command on HMC. Reference to HMC doc for how to using SMS.

Here is the `lpar_netboot` command:
```shell
lpar_netboot -i -D -f -t ent -m <client_mac> -s auto -d auto -S <server_ip> -C <client_ip> -G <gateway_ip> <lpar_name> default_profile <cec_name>
```
Note:
- <client_mac>: MAC address of client node
- <client_ip>:  IP address of client node
- <server_ip>: IP address of bastion (PXE server)
- <gateway_ip>: Network's gateway IP
- <lpar_name>: Client node lpar name in HMC
- <cec_name>: System name where the lpar resident on

### Start agent text based interactive  UI
The agent-based installer provides a text based interactive config UI, and it should be run on rendezvous host. Here are the steps to do it:
```shell
ssh core@<rendezvous_ip>
cat > agent-tui.sh << EOF
sudo mkdir -p /var/log/agent
agent_log="/var/log/agent/agent-tui.log"
agent_path="/usr/local/bin"
release_image=$(sudo cat /etc/assisted/agent-installer.env)
sudo LD_LIBRARY_PATH=${agent_path} ${release_image} AGENT_TUI_LOG_PATH=${agent_log} ${agent_path}/agent-tui
EOF
chmod +x agent-tui.sh
./agent-tui.sh
```
Here are some screens:
```
 ╔════════════════════  Agent installer network boot setup  ════════════════════╗ 
 ║┌───────────────────────────  Release image URL  ────────────────────────────┐║ 
 ║│                                                                            │║ 
 ║│ ✓ quay.io/openshift-release-dev/ocp-release@sha256:034e911a3e80ade5d3a8584…│║
 ║│                                                                            │║ 
 ║└────────────────────────────────────────────────────────────────────────────┘║ 
 ║                                                                              ║ 
 ║                        <Configure network>     <Quit>                        ║ 
 ║                                                                              ║ 
 ╚══════════════════════════════════════════════════════════════════════════════╝

   ╔════════════════════════════════════════════════════════════════════════╗
┌──║                                                                        ║──┐
│┌─║    Agent-based installer connectivity checks passed. No additional     ║─┐│
││ ║   network configuration is required.Do you still wish to modify the    ║ ││
││ ║                  network configuration for this host?                  ║…││
││ ║                                                                        ║ ││
│└─║                 This prompt will timeout in 14 seconds.                ║─┘│
│  ║                                                                        ║  │
│  ║                             <Yes>     <No>                             ║  │
│  ║                                                                        ║  │
└──╚════════════════════════════════════════════════════════════════════════╝──┘
┌─┤ NetworkManager TUI ├──┐
│                         │
│ Please select an option │
│                         │
│ Edit a connection       │
│ Activate a connection   │
│ Set system hostname     │
│                         │
│ Quit                    │
│                         │
│                    <OK> │
│                         │
└─────────────────────────┘

  ┌───────────────────────────┤ Edit Connection ├───────────────────────────┐
  │                                                                         │
  │         Profile name env32___________________________________           │
  │               Device env32 (FA:1D:67:35:13:20)_______________           │
  │                                                                         │
  │ ╤ ETHERNET                                                    <Hide>    │
  │ │ Cloned MAC address FA:1D:67:35:13:20_______________________           │
  │ │                MTU __________ (default)                               │
  │ └                                                                       │
  │ ═ 802.1X SECURITY                                             <Show>    │
  │                                                                         │
  │ ═ IPv4 CONFIGURATION <Automatic>                              <Show>    │
  │ ═ IPv6 CONFIGURATION <Disabled>                               <Show>    │
  │                                                                         │
  │ [X] Automatically connect                                               │
  │ [X] Available to all users                                              │
  │                                                                         │
  │                                                           <Cancel> <OK> │
  │                                                                         │
  │                                                                         │
  │                                                                         │
  │                                                                         │
  │                                                                         │
  └─────────────────────────────────────────────────────────────────────────┘

      ╔═════════════════════════════Network Status═════════════════════════════╗
      ║master-1                                                                ║
      ║├──Interfaces                                                           ║
      ║│  ├──env32 (ethernet)                                                  ║
      ║│  │  ├──MTU: 1500                                                      ║
      ║│  │  ├──State: up                                                      ║
   ┌──║│  │  └──IPv4 Addresses                                                 ║──┐
   │┌─║│  │     └──9.114.97.242/22                                             ║─┐│
   ││ ║│  ├──cni-podman0 (linux-bridge)                                        ║ ││
   ││ ║│  │  ├──MTU: 1500                                                      ║…││
   ││ ║│  │  ├──State: up                                                      ║ ││
   │└─║│  │  ├──IPv4 Addresses                                                 ║─┘│
   │  ║│  │  │  └──10.88.0.1/16                                                ║  │
   │  ║│  │  └──IPv6 Addresses                                                 ║  │
   │  ║│  │     └──fe80::2023:c0ff:fe28:2f8f/64                                ║  │
   └──║│  ├──lo (loopback)                                                     ║──┘
      ║│  │  ├──MTU: 65536                                                     ║
      ║│  │  ├──State: up                                                      ║
      ║│  │  ├──IPv4 Addresses                                                 ║
      ║│  │  │  └──127.0.0.1/8                                                 ║
      ║│  │  └──IPv6 Addresses                                                 ║
      ║│  │     └──::1/128                                                     ║
      ║│  └──veth54498b3f (veth)                                               ║
      ╚════════════════════════════════════════════════════════════════════════╝

```

### Monitoring the progress
After all lpars booted up with PXE, we can use `openshift-install` to monitor the progress of installation.

```shell
cd ~/agent-works
# first need to wait for bootstrap complete
./openshift-install agent wait-for bootstrap-complete --log-level=info
# after it return successfully, using following cmd to wait for completed
./openshift-install agent wait-for install-complete --log-level=info
```


Also we can use `oc` to check installation status:
```shell
export KUBECONFIG=~/agent-works/auth/kubeconfig
# check SNO node status
oc get nodes
# check installation status
oc get clusterversion
# check cluster operators
oc get co
# check pod status
oc get pod -A
```

