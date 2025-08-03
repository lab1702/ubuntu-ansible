# ubuntu-ansible

Ansible configuration that can be used with Ubuntu. Currently tested on 24.04 LTS.

## Complete Workstation Setup

### Option 1: Ansible Commands for non-root users

#### Run this once after installing the OS

    sudo apt update && sudo apt upgrade -y && sudo apt install -y git ansible

#### Run this to apply the config to your workstation

    sudo ansible-pull -U https://github.com/lab1702/ubuntu-ansible.git

#### Run this if you don't want to have to sudo docker commands

    sudo usermod -aG docker $USER

### Option 2: Ansible Commands for root users

#### Run this once after installing the OS

    apt update && apt upgrade -y && apt install -y git ansible

#### Run this to apply the config to your workstation

    ansible-pull -U https://github.com/lab1702/ubuntu-ansible.git

## WSL: Configure Edge as Default Browser

***Only on WSL!***

    sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" 200
    sudo update-alternatives --config x-www-browser

## OpenCode

    curl -fsSL https://opencode.ai/install | bash

## Rust

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

## NodeJS

*This is needed if you want to install Artillery, Claude Code, Gemini CLI and other npm packages.*

### Configure npm to install packages in user home directory

    mkdir ~/.npm-global
    npm config set prefix '~/.npm-global'
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
    export PATH=~/.npm-global/bin:$PATH

## Artillery Load Tester

    npm install -g artillery@latest

## Claude Code

    npm install -g @anthropic-ai/claude-code
