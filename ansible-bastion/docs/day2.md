# Install worker node as day2 task

Day2 task is to add a worker node to a exist OCP cluster. To do it, the playbook will reuse the information which used to create the cluster.
The current playbook only supportds Agent Based installer, Assisted Installer and SNO.

## Requirements for day2 task

The playbook requires the cluster which used the same installtion type for the day2 task. For example, if the cluster used Agent based
Installer, the day2 will use the same Agent based installer type.

Also day2 task require an exist LPAR to be used as a worker node to an exist cluster,
the LPAR need to be on the same subnet as the cluster.

## Define the vars file for day2 task

Create the vars file for playbook for day2 task. here is a sample if the `vars-day2.yaml`

```yaml
# day2 worker name must contain day2
day2_workers:
  - name: "day2-worker16"
    ipaddr: "9.114.99.109"
    macaddr: "fa:8a:b7:27:85:20"
    pvmcec: "C340F1U07-ICP-Dedicated"
    pvmlpar: "cs-pvc-sno-16-eef18018-00014bb3"
    disk: "/dev/sda"
```

* `name` - The hostname (**WITHOUT** the fqdn) of the worker node you want to set
* `ipaddr` - The IP address that you want set
* `macaddr` - The mac address for dhcp reservation
* `pvmcec` - The system name where the VM resident
* `pvmlpar` - The lpar name in system(Can be found in HMC, not name in PowerVC)
* `disk` -- Optional, the disk to install RHCOS if it is different from global definition.

**Note:** the `name` for the day2 worker node must contains the `day2`, it is used in playbook to check if a task is needed to run for day2 tasks.

## Run playbook for day2 task

The `vars-day2.yaml` is just addition of the orignal `vars.yaml` which is used to install the exist cluster. So to run playbook for day2 task as here:

```shell
ansible-playbook -e @vars.yaml -e @vars-day2.yaml playbooks/day2-main.yaml
```

Usable playbooks for day2 task are list here:

* `day2-main.yaml` - To do full day2 tasks
* `day2-1-service.yaml` - The firest step of the day2 task, setup all required sevice on bastion
* `day2-2-ignition.yaml` - The second step of the day2 task, create the day2 ignition
* `day2-3-netboot.yaml` - The third step of day2 task, use `lpar_netboot` to boot up the LPAR
* `day2-4-monitor.yaml` - The fourth step of day2 task, monitor the day2 installation

