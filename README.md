# lb-azure-deployment-automation
A set of scripts to automate the configuration and deployment of Lightbits in Azure

## Scripts
1. configure_installer.sh
2. configure_target.sh
3. lightbits_deploy.sh

## Use

### Configure Installer
This script will take a standard Azure RHEL 8.6 machine and get it ready to install Lightbits using Ansible.

1. Download file onto installer machine running RHEL 8.6 in Azure
2. Run:
```
sudo bash configure_installer.sh -t ${Lightbits_repo_token}
```

### Configure Target
This script will take a standard Azure RHEL 8.6 machine and get it ready to be a target for Lightbits.

1. Download file onto Lightbits target node running RHEL 8.6 in Azure
2. Run:
```
sudo bash configure_target.sh
```

### Lightbits Deploy (Configure Mode)
> **_NOTE:_** This script must be run AFTER the configure_installer and configure_target, otherwise it'll fail.
This script will configure the ansible files for a given Azure storage VM.

1. Download file onto installer that has already run "configure_installer.sh"
2. Move file into working directory with "ansible.cfg" file
3. Run:
```
sudo bash lightbits_deploy.sh -m configure -n l16s_v3 -i "10.0.0.1,10.0.0.2,10.0.0.3" -k /home/azureuser/key.pem -t 'LIGHTBITSREPOTOKEN'
```

### Lightbits Deploy (Installer Mode)
> **_NOTE:_** This script must be run AFTER the lightbits_deploy.sh -m configure has been run. Essentially, Ansible needs to be good to go.
This script will run the ansible playbooks to install Lightbits via a docker container.

1. Run:
```
sudo bash lightbits_deploy.sh -m install
```