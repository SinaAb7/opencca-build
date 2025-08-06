# OpenCCA

## Getting Started

We build OpenCCA in an x86-docker container. Make sure to have the prerequiresites installed.

### Install Prerequisites
1. [Repo](https://gerrit.googlesource.com/git-repo)
2. [Docker](https://docs.docker.com/engine/install/)
3. make and git:
```
sudo apt install git make
```

> ⚠️ We need a recent version of Docker. Version 24.0.7 worked for us.


### Download Code

> 💡 **Tip:** A CI job reproduces the subsequent steps in a tutorial:
>   
> [![quick-start tutorial](https://github.com/opencca/opencca-build/actions/workflows/tutorial.yml/badge.svg?branch=opencca%2Fmain)](https://github.com/opencca/opencca-build/actions/workflows/tutorial.yml)

Create the base directories and clone the code:

```sh
mkdir -p opencca/snapshot && cd opencca

#  Use --depth=10 to reduce git history and speed up clone
repo init -u https://github.com/opencca/opencca-manifest.git \
    -b opencca/systex25 \
    -m systex25.xml

repo sync --all -j5 --fetch-submodules

```

We provide a [development container](./docker/) ([registry](https://github.com/opencca/opencca-build/pkgs/container/opencca-build)) to cross-compile all artifacts. Pull and run it:

```sh
cd opencca-build/docker
make pull
make start
make enter # Enter the container
```

### Build It

Build all components (inside container)
```sh
cd opencca-build/scripts/ && build_all.sh
```
> 💡 **Tip:** Read `build_all.sh` for instructions how to build the individual firmware components.

Upon build completion, you find all build artifacts in `/opencca/snapshot.`
What's next is to [flash the firmware](https://github.com/opencca/opencca-flash) on to the hardware.

