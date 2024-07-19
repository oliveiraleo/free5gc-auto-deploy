# free5GC-auto-deploy

This repository comprises a collection of scripts designed to facilitate the deployment of instances of the [free5GC](https://github.com/free5gc/free5gc) project.

The comprehensive documentation available on the [project's official website](https://free5gc.org/guide/) is highly advisable for individuals new to free5GC to familiarize themselves with. The underlying processes are to be carefully studied, as the scripts are designed to replicate the steps outlined in the ["Build free5GC from scratch"](https://free5gc.org/guide/#advanced-build-free5gc-from-scratch) guide in an automated manner.

## Notice

The scripts available on this repository have been based on free5GC's [advanced setup](https://free5gc.org/guide/#advanced-build-free5gc-from-scratch) instructions. However, instead of having two separate interfaces (one for remote access and other for general use), they have been designed considering a environment where the 5GC machine has only one network interface available.

## Motivation

In the course of my research, I've been utilizing the free5GC project. During the experimentation with this 5G Core (5GC) [advanced setup](https://free5gc.org/guide/#advanced-build-free5gc-from-scratch) and its associated Network Functions (NFs), I discovered an opportunity to streamline the installation process. By automating various installation tasks, I significantly reduced deployment time, optimizing efficiency and enabling a more agile research environment.

During the process of seeking a similar tool, I've found 301 repositories hosted on Github that [had the word "free5gc" on them](https://github.com/search?q=free5gc+created%3A%3C2024-02-21&type=Repositories&ref=advsearch&l=&l=). As I took a deeper look, I noted that:
- 23 (7.6%) were [related to Kubernetes](https://github.com/search?q=free5gc+k8s+OR+free5gc+microk8s+OR+free5gc+kubernetes+created%3A%3C2024-02-21+&type=repositories&ref=advsearch);
- 27 (9.0%) were [related to docker but not to Kubernetes](https://github.com/search?q=free5gc+docker+NOT+%28kubernetes+OR+k8s+OR+microk8s+OR+powder%29+created%3A%3C2024-02-21&type=repositories&ref=advsearch);
- 35 (11.6%) were [written in Shell Script](https://github.com/search?q=free5gc+language%3AShell&type=repositories&ref=advsearch);
- Additional forms of automation (e.g. For [AWS environments](https://github.com/search?q=free5gc+aws+created%3A%3C2024-02-21&type=repositories&ref=advsearch)) were found too

However the focus of my scripts were to (semi-)automatically deploy free5GC, and I couldn't find any projects that would fit this purpose.

Entering into the spirit of FSFE's ([FSF](https://www.fsf.org/) Europe) campaign ["Public Money? Public Code!"](https://fsfe.org/activities/publiccode/publiccode.en.html) and given that my research is currently being funded by public administration entities (namely [CAPES](https://www.gov.br/capes) and [RNP](https://www.rnp.br/en)) I decided to share my code with the community as it may help others in the future.

## Requirements

The scripts were tested within an environment that possessed the following characteristics:

### Software

- Bash shell 5.0.17 (or later)
- Ubuntu Server 20.04.6
- Linux Kernel 5.4.x (tested on 5.4.0-189-generic)

### Hardware (minimum)

- 20GB HDD
- 2GB RAM
- 1x i5 processor CPU core

### Hardware (recommended)

- 40GB HDD
- 4GB RAM
- 2x i5 processor CPU core

For more information see [this FAQ](./FAQ.md#q3-the-minimum-requirements-reported-by-your-script-are-quite-lower-than-the-ones-from-the-free5gcs-official-documentation-why)

## Usage

### On free5GC machine:

Download the scripts (stable version)

```
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/v1.2.1/install-go.sh
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/v1.2.1/deploy-free5gc.sh
chmod +x deploy-free5gc.sh install-go.sh # gives execution permission
```

**Tip:** Swap `main` with the desired version to use other curl commands in this README

**Note:** Check the [releases page](https://github.com/oliveiraleo/free5gc-auto-deploy/releases/) for newer versions or use the [latest stable](https://github.com/oliveiraleo/free5gc-auto-deploy/releases/latest)


Download the scripts (nightly version)

```
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/install-go.sh
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/deploy-free5gc.sh
chmod +x deploy-free5gc.sh install-go.sh # gives execution permission
```
**Tip:** Use `-LOSs` instead of `-LO` to suppress curl's output messages (for more information see [this page](https://linux.die.net/man/1/curl))

Install Go and reload the environment vars

```
./install-go.sh && source ~/.bashrc
```

Then install free5gc

```
./deploy-free5gc.sh
```

**Note:** Unless otherwise specified, the script will automatically install the stable version defined by the FREE5GC_VERSION variable, without making any changes to the N3IWF configuration

#### Script parameters

Currently, `deploy-free5gc.sh` script accepts three parameters:

- `-nightly`: Clones free5GC nightly version set by FREE5GC_NIGHTLY_COMMIT variable instead of the stable one
- `-n3iwf`: Prepares the configuration file of the N3IWF during the installation
- `-reset-firewall`: Removes all the rules from iptables during the installation

Example usage:

```
./deploy-free5gc.sh -nightly -n3iwf
```

### On UERANSIM machine:

Download the script

```
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/deploy-UERANSIM.sh
chmod +x deploy-UERANSIM.sh # gives execution permission
```

Then install UERANSIM
```
./deploy-UERANSIM.sh -stable
```

#### Script parameters

Currently, `deploy-UERANSIM.sh` script accepts four parameters:

- `-stable`: Clones UERANSIM stable version
- `-nightly33`: Clones UERANSIM nightly version compatible with free5GC v3.3.0 or below
- `-nightly`: Clones UERANSIM nightly version compatible with free5GC v3.4.0 or above
- `-keep-hostname`: Disables changing the machine hostname during the deploy

Example usage:

```
./deploy-UERANSIM.sh -nightly
```

**Note:** This script requires a "version related" parameter to work. Please select one from the list provided above that is compatible with your environment

#### Add new 5G UE to free5GC

Please, follow the instructions from [this page](https://free5gc.org/guide/5-install-ueransim/#4-use-webconsole-to-add-an-ue)

#### UERANSIM basic usage

To deploy the gNB:

```
cd ~/UERANSIM
build/nr-gnb -c config/free5gc-gnb.yaml
```

To deploy the UE:

```
cd ~/UERANSIM
sudo build/nr-ue -c config/free5gc-ue.yaml # for multiple-UEs, use -n and -t for number and delay
```

### On N3IWUE machine:

Download the scripts

```
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/install-go.sh
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/deploy-n3iwue.sh
chmod +x deploy-n3iwue.sh install-go.sh # gives execution permission
```

Install Go and reload the environment vars

```
./install-go.sh && source ~/.bashrc
```

Then install N3IWUE
```
./deploy-n3iwue.sh
```

#### Script parameters

Currently, `deploy-n3iwue.sh` script accepts two parameters:

- `-keep-hostname`: Disables changing the machine hostname during the deploy
- `-latest`: Installs N3IWUE latest version (currently v1.0.1)

Example usage:

```
./deploy-n3iwue.sh -keep-hostname -latest
```

#### Add new N3IWUE to free5GC

Please, follow the instructions from [this page](https://free5gc.org/guide/n3iwue-installation/#3-use-webconsole-to-add-ue)

#### N3IWUE basic usage

To deploy the N3IWUE:
```
cd ~/n3iwue
./run.sh

```

### How to deploy both UERANSIM and N3IWUE

On a new machine, download the script

```
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/deploy-both-UEs.sh
```

Then execute it using an interactive shell

```
bash -i deploy-both-UEs.sh
```

**Note:** By default shells invoked by a script are non-interactive, running this script in a non-interactive shell will cause bash environment reload to fail after Go installation. For more information see [this page](https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Interactive-Shells)

## Contributing

The community is encouraged to contribute to this project. If you identify any opportunities for improvement or areas that require updates due to upstream changes, please feel free to open an [issue](https://github.com/oliveiraleo/free5gc-auto-deploy/issues) or [pull request](https://github.com/oliveiraleo/free5gc-auto-deploy/pulls)

All contributions to this repository are subject to its [licensing terms](./LICENSE). For more information, please see [here](https://www.gnu.org/licenses/gpl-3.0.en.html) and [here](https://choosealicense.com/licenses/gpl-3.0/).

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3 as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
