# OpenCCA Container


### Getting Started

To get started, ensure to have the following
dependencies installed:

 > git, make, docker

<details>
<summary>Prerequisite: Install docker</summary>

For installation methods see https://docs.docker.com/engine/install/

```sh
# Docker on Ubuntu

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update


sudo apt-get install docker-ce docker-ce-cli containerd.io \
             docker-buildx-plugin docker-compose-plugin
sudo chmod 777 /var/run/docker.sock
```

Verify installation:

```sh
docker run hello-world
```
</details>  

<details>
<summary>Prerequisite: Install make</summary>

```sh
# On Ubuntu
sudo apt install -y make
```

</details>

<details>
<summary>Prerequisite: Install git</summary>

```sh
# On Ubuntu
sudo apt install -y git
```

</details>



### Building OpenCCA
```
# Build and enter container
make -f opencca-build/docker/Makefile help
make -f opencca-build/docker/Makefile build
make -f opencca-build/docker/Makefile start
make -f opencca-build/docker/Makefile enter
```

