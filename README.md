# ubuntu-ansible

Ansible configuration that can be used with Ubuntu. Currently tested on 24.04 LTS.

## Complete Workstation Setup

### Ansible Commands

#### Run this once after installing the OS

    sudo apt update && sudo apt upgrade -y && sudo apt install -y git ansible

#### Run this to apply the config to your workstation with OS package for R

    sudo ansible-pull -U https://github.com/lab1702/ubuntu-ansible.git

#### Run this to apply the config to your workstation with CRAN package for R

    sudo ansible-pull -U https://github.com/lab1702/ubuntu-ansible.git --extra-vars "cran=true"

#### Run this if you don't want to have to sudo docker commands

    sudo usermod -aG docker $USER

### Ansible Commands for root users

#### Run this once after installing the OS

    apt update && apt upgrade -y && apt install -y git ansible

#### Run this to apply the config to your workstation with OS package for R

    ansible-pull -U https://github.com/lab1702/ubuntu-ansible.git

#### Run this to apply the config to your workstation with CRAN package for R

    ansible-pull -U https://github.com/lab1702/ubuntu-ansible.git --extra-vars "cran=true"

## Configure Edge as default browser in WSL

    sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" 200
    sudo update-alternatives --config x-www-browser

### Download Warp Terminal

    wget https://raw.githubusercontent.com/lab1702/warp-downloader/refs/heads/main/download-warp.sh
    bash download-warp.sh
    rm download-warp.sh

## Download RStudio

    wget https://raw.githubusercontent.com/lab1702/rstudio-downloader/refs/heads/main/download-rstudio.sh
    bash download-rstudio.sh
    rm download-rstudio.sh

## AI Tools

### Configure npm to install packages in user home directory

    mkdir ~/.npm-global
    npm config set prefix '~/.npm-global'
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.profile
    export PATH=~/.npm-global/bin:$PATH

### Install Claude Code

    npm install -g @anthropic-ai/claude-code

#### Update Claude Code

    claude update

### Install Gemini CLI

    npm install -g @google/gemini-cli

#### Update Gemini CLI

    npm upgrade -g @google/gemini-cli
