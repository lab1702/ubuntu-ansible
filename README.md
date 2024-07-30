# ubuntu-ansible

Ansible configuration that can be used with Ubuntu. Currently tested on 24.04 LTS.

## Complete Workstation Setup

### Ansible Commands

#### Run this once after installing the OS

    sudo apt update && sudo apt upgrade -y && sudo apt install -y git ansible

#### Run this to apply the config to your workstation

    sudo ansible-pull -U https://github.com/lab1702/ubuntu-ansible.git --extra-vars "host_user=${USER}"

## OneDrive

### Initial Authentication

    onedrive

### Initial Sync

    onedrive --synchronize

### Enable Monitoring

    sudo systemctl enable onedrive@${USER}.service
    sudo systemctl start onedrive@${USER}.service

### Watch Logs

    sudo journalctl --unit=onedrive@${USER} -f
