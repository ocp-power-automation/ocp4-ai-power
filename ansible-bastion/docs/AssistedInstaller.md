# Using OpenShift Assisted Installer for PowerVM

The latest OpenShift Assisted Installer release has added the support for Power. The Assisted Installer provides two ways to install OpenShift: 
- Using [Web UI](https://console.redhat.com/openshift/assisted-installer/clusters/~new), it simplify the OCP installation.
- Using [REST API](https://api.openshift.com/api/assisted-install/v2), it can be used for automation.

Here we will use the UI method to create OCP for Power. 

## Requirements for installing OpenShift with Assisted Installer

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
- 9.114.98.8 -- Bastion's IP
- 9.114.96.1 -- Network route or gateway
- assisted.ibm.com  -- OCP's domain name
- p9-ha -- OCP's cluster_id
- 9.114.97.x -- OCP node IPs


### Setup dnsmasq

Here is a sample configuration file for `/etc/dnsmasq.conf`:
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
domain=p9-ha.assisted.ibm.com
local=/p9-ha.assisted.ibm.com/
address=/apps.p9-ha.assisted.ibm.com/9.114.98.8
server=9.9.9.9

addn-hosts=/etc/dnsmasq.d/addnhosts


##################################
# DHCP
##################################
dhcp-ignore=tag:!known
dhcp-leasefile=/var/lib/dnsmasq/dnsmasq.leases

dhcp-range=9.114.97.242,static

dhcp-option=option:router,9.114.96.1
dhcp-option=option:netmask,255.255.252.0
dhcp-option=option:dns-server,9.114.98.8


dhcp-host=fa:1d:67:35:13:20,master-1,9.114.97.242,infinite
dhcp-host=fa:41:fb:ed:77:20,master-2,9.114.97.231,infinite
dhcp-host=fa:31:cd:db:a5:20,master-3,9.114.97.225,infinite


###############################
# PXE
###############################
enable-tftp
tftp-root=/var/lib/tftpboot
dhcp-boot=boot/grub2/powerpc-ieee1275/core.elf
```

and `/etc/dnsmasq.d/addnhosts` file:
```
9.114.98.8 api api-int
9.114.97.242 master-1
9.114.97.231 master-2
9.114.97.225 master-3
```

### PXE setup
To enable PXE for PowerVM, we need to install `grub2` with:
```shell
grub2-mknetdir --net-directory=/var/lib/tftpboot
```

Here is the sample `/var/lib/tftpboot/boot/grub2/grub.cfg`:
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
   linux "/rhcos/kernel" ip=dhcp rd.neednet=1 ignition.platform.id=metal ignition.firstboot coreos.live.rootfs_url=http://9.114.98.8:8000/install/rootfs.img ignition.config.url=http://9.114.98.8:8000/ignition/assisted.ign

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
   linux "/rhcos/kernel" ip=dhcp rd.neednet=1 ignition.platform.id=metal ignition.firstboot coreos.live.rootfs_url=http://9.114.98.8:8000/install/rootfs.img ignition.config.url=http://9.114.98.8:8000/ignition/assisted.ign

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
   linux "/rhcos/kernel" ip=dhcp rd.neednet=1 ignition.platform.id=metal ignition.firstboot coreos.live.rootfs_url=http://9.114.98.8:8000/install/rootfs.img ignition.config.url=http://9.114.98.8:8000/ignition/assisted.ign

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
    server master-1 9.114.97.242:6443 check
    server master-2 9.114.97.231:6443 check
    server master-3 9.114.97.225:6443 check

frontend machine-config-server
    bind *:22623
    default_backend machine-config-server
    option tcplog

backend machine-config-server
    balance source
    server master-1 9.114.97.242:22623 check
    server master-2 9.114.97.231:22623 check
    server master-3 9.114.97.225:22623 check

frontend machine-config-server-day2
    bind *:22624
    default_backend machine-config-server-day2
    option tcplog

backend machine-config-server-day2
    balance source
    server master-1 9.114.97.242:22624 check
    server master-2 9.114.97.231:22624 check
    server master-3 9.114.97.225:22624 check

frontend ingress-http
    bind *:80
    default_backend ingress-http
    option tcplog

backend ingress-http
    balance source
    server master-1-http-router0 9.114.97.242:80 check
    server master-2-http-router1 9.114.97.231:80 check
    server master-3-http-router2 9.114.97.225:80 check

frontend ingress-https
    bind *:443
    default_backend ingress-https
    option tcplog

backend ingress-https
    balance source
    server master-1-https-router0 9.114.97.242:443 check
    server master-2-https-router1 9.114.97.231:443 check
    server master-3-https-router2 9.114.97.225:443 check

#---------------------------------------------------------------------

```

## Create Assisted Installer discovery ISO
Access to Assisted Installer [WEB UI](https://console.redhat.com/openshift/assisted-installer/clusters/~new) and create the cluster:
1. Log in to the [WEB UI](https://console.redhat.com/openshift/assisted-installer/clusters), click the `Create Cluster` to open cluster detail view
&nbsp;
![AI Cluster list view](./images/Screen-0-assisted-cluster-view.png)
&nbsp;
2.  Fill out required fields, then click `Next` to go next view
&nbsp;
![Cluster detail view](./images/Screen-1-cluster-details.png)
&nbsp;
3. Skip the `Operators` selection, click `Next` to go `Host Discovery` view
&nbsp;
![Operators view](./images/Screen-2-operators.png)
&nbsp;
4. At `Host Discovery`, click `Add Hosts` to open `Add Hosts` popup dialog
&nbsp;
![Host Discovery](./images/Screen-3-host-discovery.png)
&nbsp;
5. At `Add Hosts` popup dialog, select `Full image` and fill in SSH public key, click `Generate Discovery ISO` to go next step
&nbsp;
![Add Hosts - 1](./images/Screen-3-host-discovery-add-host-1.png)
&nbsp;
6. At `Add Hosts` popup dialog, save the URL for download `Discovery ISO` for late use
&nbsp;
![Add Hosts - 2](./images/Screen-3-host-discovery-add-hosts-2.png)
&nbsp;

### Download discovery ISO and setup PXE 
Download the generated discovery ISO to bastion, and extract the ignition file and PXE files fro the ISO:
```shell
mkdir -p ~/ai-works
cd ~/ai-works
# download discovery ISO
wget -O ai-discovery.iso 'https://api.openshift.com/api/assisted-images/images/1f434f83-944a-45e3-bf19-17b46af1f6de?arch=ppc64le&image_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2ODM4Mjk2NDYsInN1YiI6IjFmNDM0ZjgzLTk0NGEtNDVlMy1iZjE5LTE3YjQ2YWYxZjZkZSJ9.ufD-6DovhpftDYma4OJzLxbUD0MOQOpEbdYou-xkiVQ&type=full-iso&version=4.13'
# extract ignition file from ISO
coreos-installer iso ignition show ai-discovery.iso > assisted.ign
coreos-installer iso extract pxe ai-discovery.iso 
# copy the ignition file assisted.ign to http's ignition directory
cp assisted.ign /var/www/html/ignition/.
# copy rootfs.img to http's install directory
cp  ai-discovery-rootfs.img /var/www/html/install/rootfs.img
restorecon -vR /var/www/html || true
# copy PXE files to it's directory:
cp ai-discovery-vmlinuz /var/lib/tftpboot/rhcos/kernel
cp ai-discovery--initrd.img /var/lib/tftpboot/rhcos/initramfs.img
```

Now `bastion` has all required files and configurations to install OCP.

## Start installation
There two steps for AI installation, first the all LPARs need to boot up with PXE, then monitor the installation progress in WEB UI.

### Network boot all nodes
To boot PowerVM with netboot, there are two ways to do it: using SMS interactively to select bootp or using `lpar_netboot`  command on HMC. Reference to HMC doc for how to using SMS.

Here is the `lpar_netboot` command:
```shell
lpar_netboot -i -D -f -t ent -m <sno_mac> -s auto -d auto -S <server_ip> -C <sno_ip> -G <gateway> <lpar_name> default_profile <cec_name>
```
Note:
- <sno_mac>: MAC address of node
- <sno_ip>:  IP address of node
- <server_ip>: IP address of bastion (PXE server)
- <gateway>: Network's gateway IP
- <lpar_name>: Node lpar name in HMC
- <cec_name>: System name where the lpar resident on


### Monitoring the progress
After all nodes boot up with PXE, we can go back to Web UI to monitor the progress of installation.

1.  At `Host discovery`, waiting for all hosts' state become `Ready`, then click `Next` go to `Storage` view
&nbsp;
![Cluster inventory](./images/Screen-3-host-discovery-inventory.png)
&nbsp;
2.  At `Storage`, click `Next` go to `Networking` view
&nbsp;
![Cluster storage](./images/Screen-4-storage.png)
&nbsp;
3.  At `Networking`, select `User-Managed Networking` for Power, then click `Next` go to `Review and create` view
&nbsp;
![Cluster networking](./images/Screen-5-networking.png)
&nbsp;
4.  At `Review and create`, review all information for the cluster, then click `Install Cluster` to start installation
&nbsp;
![Cluster review and create](./images/Screen-6-review-create.png)
&nbsp;
5.  At `Installation progress`, monitor the progress of the cluster installation
&nbsp;
![Cluster install progress](./images/Screen-7-installation-progress.png)
&nbsp;
6. Click the `View Cluster Events` to open popup to get detail events
&nbsp;
![Cluster install progress events](./images/Screen-8-cluster-events.png)
&nbsp;
7. Installation completed
&nbsp;
![Cluster install done](./images/Screen-9-cluster-done.png)
&nbsp;

At the cluster detail view, click `Download kubeconfig` to download the kubeconfig and save to `~/ai-works`, and got the password for `kubeadmin` for cluster.
 
Also we can use `oc` to check installation status:
```shell
export KUBECONFIG=~/ai-works/kubeconfig
# check SNO node status
oc get nodes
# check installation status
oc get clusterversion
# check cluster operators
oc get co
# check pod status
oc get pod -A
```

