# debian-ansible

## Simple Docker Host Setup

If you plan to do everything in [Docker](https://www.docker.com/) you do not need everything in this [Ansible](https://www.ansible.com/) configuration
and can simply run this to get pre-requisites installed.

### Docker Host Commands

Run this after installing the OS:

    sudo apt update && sudo apt install -y git vim docker.io docker-compose
    sudo usermod -a -G docker $USER
    
## Complete Workstation Setup

### Ansible Commands

Run this once after installing the OS:

    sudo apt update && sudo apt install -y git ansible

Run this to apply the config to your workstation:

    sudo ansible-pull -U https://github.com/lab1702/debian-ansible.git --extra-vars "host_user=$USER"

## RStudio

To install RStudio Desktop, RStudio Server or Shiny Server, follow instructions at [https://posit.co/](https://posit.co/) to get latest versions.
