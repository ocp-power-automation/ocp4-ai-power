# **Table of Contents**

- [**Table of Contents**](#table-of-contents)
- [Introduction](#introduction)
- [Automation Host Prerequisites](#automation-host-prerequisites)
- [PowerVC Prerequisites](#powervc-prerequisites)
- [OCP Install](#ocp-install)


# Introduction
The `ocp4-ai-power/tf-powervc` [project](https://github.com/ocp-power-automation/ocp4-ai-power) provides Terraform based automation code to help the deployment of OpenShift Container Platform (OCP) 4.x on PowerVM systems managed by PowerVC.

!!! Note
        For bugs/enhancement requests etc. please open a GitHub [issue](https://github.com/ocp-power-automation/ocp4-ai-power/issues)

# Automation Host Prerequisites

The automation needs to run from a system with internet access. This could be your laptop or a VM with public internet connectivity. This automation code has been tested on the following 64-bit Operating Systems:
- Mac OSX (Darwin)
- Linux (x86_64/ppc64le)
- Windows 10

Follow the [guide](docs/automation_host_prereqs.md) to complete the prerequisites.


# PowerVC Prerequisites

Follow the [guide](docs/ocp_prereqs_powervc.md) to complete the PowerVC prerequisites.

# OCP Install

Follow the [quickstart](docs/quickstart.md) guide for OCP installation on PowerVM LPARs managed via PowerVC
