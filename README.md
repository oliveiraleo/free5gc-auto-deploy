# free5GC-auto-deploy

This repository contains scripts that help to deploy instances of the [free5GC](https://github.com/free5gc/free5gc) project.

## Motivation

In the course of my research, I've been utilizing the free5GC project. During the experimentation with this 5G Core (5GC) [advanced setup](https://free5gc.org/guide/#advanced-build-free5gc-from-scratch) and its associated Network Functions (NFs), I discovered an opportunity to streamline the installation process. By automating various installation tasks, I significantly reduced deployment time, optimizing efficiency and enabling a more agile research environment.

During the process of seeking a similar tool, I've found 301 repositories hosted on Github that [had the word "free5gc" on them](https://github.com/search?q=free5gc+created%3A%3C2024-02-21&type=Repositories&ref=advsearch&l=&l=). As I took a deeper look, I noted that:
- 23 (7.6%) were [related to Kubernetes](https://github.com/search?q=free5gc+k8s+OR+free5gc+microk8s+OR+free5gc+kubernetes+created%3A%3C2024-02-21+&type=repositories&ref=advsearch);
- 27 (9.0%) were [related to docker but not to Kubernetes](https://github.com/search?q=free5gc+docker+NOT+%28kubernetes+OR+k8s+OR+microk8s+OR+powder%29+created%3A%3C2024-02-21&type=repositories&ref=advsearch);
- 35 (11.6%) were [written in Shell Script](https://github.com/search?q=free5gc+language%3AShell&type=repositories&ref=advsearch);
- Additional forms of automation (e.g. For [AWS environments](https://github.com/search?q=free5gc+aws+created%3A%3C2024-02-21&type=repositories&ref=advsearch)) were found too

However the focus of my scripts were to (semi-)automatically deploy free5GC, and I couldn't find any projects that would fit this purpose.

Entering into the spirit of FSFE's (FSF Europe) campaign ["Public Money? Public Code!"](https://fsfe.org/activities/publiccode/publiccode.en.html) and given that my research is currently being funded by public administration entities (namely [CAPES](https://www.gov.br/capes) and [RNP](https://www.rnp.br/en)) I decided to share my code with the community as it may help others in the future.

## Requirements

Those are the characteristics of the environment where the scripts were tested

### Software

- Bash shell 5.0.17 (or later)
- Ubuntu Server 20.04.6

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

Download the scripts

```
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/install-go.sh
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/deploy-free5gc.sh
chmod +x deploy-free5gc.sh install-go.sh # gives execution permission
```
**Tip:** Use `-LOSs` instead of `-LO` to suppress curl's output messages (for more information see [this page](https://linux.die.net/man/1/curl))

Install go and reload the environment vars

```
./install-go.sh && source ~/.bashrc
```

Then install free5gc

```
./deploy-free5gc.sh
```

**Note:** By default, the script will install the stable version set by FREE5GC_VERSION variable and will **not** touch N3IWF configuration 

#### Script parameters

Currently, `deploy-free5gc.sh` script accepts two parameters:

- `-nightly`: Clones free5GC nightly version set by FREE5GC_NIGHTLY_COMMIT variable instead of the stable one
- `-n3iwf`: Prepares the configuration file of the N3IWF during the installation

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
./deploy-UERANSIM.sh
```

## Contributing

Contributions from the community are encouraged. If you saw any improvements that could be made or something that must be updated due to upstream changes, please, feel free to open an [issue](https://github.com/oliveiraleo/free5gc-auto-deploy/issues) or a [pull request](https://github.com/oliveiraleo/free5gc-auto-deploy/pulls)

All the contributions of source code to this repository are subject to its [license](./LICENSE). For more information see [here](https://www.gnu.org/licenses/gpl-3.0.en.html) and [here](https://choosealicense.com/licenses/gpl-3.0/).

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3 as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
