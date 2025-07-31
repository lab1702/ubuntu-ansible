# ubuntu-ansible

Ansible configuration that can be used with Ubuntu. Currently tested on 24.04 LTS.

## Complete Workstation Setup

### Ansible Commands for non-root users

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

***Only on WSL!***

    sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" 200
    sudo update-alternatives --config x-www-browser

## Install OpenCode

    curl -fsSL https://opencode.ai/install | bash

## Download RStudio

    wget https://raw.githubusercontent.com/lab1702/rstudio-downloader/refs/heads/main/download-rstudio.sh
    bash download-rstudio.sh
    rm download-rstudio.sh

## NodeJS NPM Setup

*This is needed if you want to install Claude Code, Gemini CLI and other npm packages.*

### Configure npm to install packages in user home directory

    mkdir ~/.npm-global
    npm config set prefix '~/.npm-global'
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
    export PATH=~/.npm-global/bin:$PATH

## Artillery Load Tester Setup

    npm install -g artillery@latest
