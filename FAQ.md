# Frequently Asked Questions

## Q1: Why did you use Ubuntu 20.04 instead of 22.04?

**A:** By the time I wrote those scripts free5gc was tested by its developers in Ubuntu Server 20.04.6 (see [this snapshot](https://web.archive.org/web/20240220132833/https://free5gc.org/guide/Environment/)). Another point to consider is that, the kernel version officially supported by the [GTP-U module](https://github.com/free5gc/gtp5g) is 5.4.x (which comes by default on Ubuntu 20.04.x). On top of that, newer kernel versions (like 5.1x and 6.2) had some glitches (for examples, see those issues [here](https://github.com/free5gc/free5gc/issues/348) and [here](https://github.com/free5gc/free5gc/issues/524)) and Ubuntu 22.04 faced some hiccups (example [here](https://github.com/free5gc/free5gc/issues/513))

## Q2: I see your point, but anyway, isn't Ubuntu 20.04 already outdated?

**A:** As mentioned on a [message on its official blog](https://ubuntu.com/blog/ubuntu-server-20-04) and on the [release cycle page](https://ubuntu.com/about/release-cycle), Ubuntu 20.04 will be supported until April 2025 which gives some time for free5gc's developers to update/adapt/test the project (and its dependencies) on the new 22.04 LTS release.

## Q3: The minimum requirements reported by your script are quite lower than the ones from the free5gc's official documentation. Why?

A: The requirements from there (available on [this page](https://free5gc.org/guide/Environment/)) were designed to work in production grade environment where 5G devices would connect, etc. My target environment is a testing one with only a small number of simulated devices connected. Because of that, I've tried to scale down the requirements as much as possible. Anyway, the machine where the scripts will run may be adapted to your preferences.

