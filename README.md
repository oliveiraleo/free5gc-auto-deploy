# free5GC-auto-deploy

## Motivation

TBA

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

- On 5GC machhine:

Download the scripts

```
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/install-go.sh
curl -LO https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/deploy-free5gc.sh
chmod +x auto-deploy-5gc.sh install-go.sh # gives execution permission
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

- On UERANSIM machine:

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
