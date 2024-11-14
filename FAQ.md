# Frequently Asked Questions

## Q1: Why did you use Ubuntu 20.04 instead of 22.04?

**A:** By the time I wrote those scripts free5GC was tested by its developers in Ubuntu Server 20.04.6 (see [this snapshot](https://web.archive.org/web/20240220132833/https://free5gc.org/guide/Environment/)). Another point to consider is that, the kernel version officially supported by the [GTP-U module](https://github.com/free5gc/gtp5g) is 5.4.x (which comes by default on Ubuntu 20.04.x). On top of that, newer kernel versions (like 5.1x and 6.2) had some glitches (for example, see those issues [here](https://github.com/free5gc/free5gc/issues/348) and [here](https://github.com/free5gc/free5gc/issues/524)) and Ubuntu 22.04 faced some hiccups (example [here](https://github.com/free5gc/free5gc/issues/513))

## Q2: I see your point, but anyway, isn't Ubuntu 20.04 already outdated?

**A:** As mentioned on a [message on its official blog](https://ubuntu.com/blog/ubuntu-server-20-04) and on the [release cycle page](https://ubuntu.com/about/release-cycle), Ubuntu 20.04 will be supported until April 2025 which gives some time for free5GC's developers to update/adapt/test the project (and its dependencies) on the new 22.04 LTS release.

## Q3: The minimum requirements reported by your script are quite lower than the ones on the free5GC's official documentation. Why?

A: The requirements from there (available on [this page](https://free5gc.org/guide/Environment/)) were designed to work in a production grade environment where 5G devices would connect, etc. My target environment is a testing one with only a small number of simulated devices connected. Because of that, I've tried to scale down the requirements as much as possible. Anyway, the machine where the scripts will run may be adapted to your preferences, the amount of RAM and CPU power available will affect the time required to build the software (e.g. free5GC NFs, UERANSIM...), the number of connected devices and the general performance of the environment.

## Q4: Support for Ubuntu 22.04 was added to your tool. Do you recommend using it now?

A: No, I don't. Specially if a stable environment is required (see [FAQ #1](#q1-why-did-you-use-ubuntu-2004-instead-of-2204)). Support for this Ubuntu version was added just to test newer versions of the kernel and free5GC's support for Ubuntu 22.04.

## Q5: What is the most up to date kernel you've tested your tool on?

**A:** Currently, kernel 5.15.x, more specifically `5.15.0-116-generic`. If a newer kernel is a requirement (e.g. to use MPTCP), perhaps you may use this version on an Ubuntu 20.04 installation.
