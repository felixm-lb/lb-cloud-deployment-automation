#!/usr/bin/bash
# This script will configure a Lightbits target VM ready to install Lightbits

DisplayHelp()
{
    # Display help menu
    echo "This script will configure the target VMs ready to install Lightbits - we're assuming you've deployed RHEL 8.6 Gen 2 on Azure!
   
    Syntax: $FUNCNAME [-h]
    options:                                    example:
    h   Display This Help.
"
}

# Get entered options and set them as variables
SetOptions()
{
    # Get and set the options
    local OPTIND
    while getopts ":h:v:t:b:" option; do
        case "${option}" in
            h)
                DisplayHelp
                exit;;
            :)
                if [ "${OPTARG}" != "h" ]; then
                    printf "missing argument for -%s\n" "$OPTARG" >&2
                fi
                DisplayHelp
                exit 1
                ;;
            \?)
                printf "illegal option: -%s\n" "$OPTARG" >&2
                DisplayHelp
                exit 1
                ;;
        esac
    done
    shift $((OPTIND-1))
}

InstallSoftware()
{
    echo "Installing required packages"
    sudo yum install -y wget

    echo "Pulling kernel using Alma (free repos)"
    wget https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/Packages/kernel-core-4.18.0-425.3.1.el8.x86_64.rpm
    wget https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/Packages/kernel-modules-4.18.0-425.3.1.el8.x86_64.rpm
    wget https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/Packages/kernel-modules-extra-4.18.0-425.3.1.el8.x86_64.rpm
    wget https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/Packages/kernel-4.18.0-425.3.1.el8.x86_64.rpm

    echo "Installing kernel packages"
    sudo rpm -i kernel-core-4.18.0-425.3.1.el8.x86_64.rpm
    sudo rpm -i kernel-modules-4.18.0-425.3.1.el8.x86_64.rpm
    sudo rpm -i kernel-modules-extra-4.18.0-425.3.1.el8.x86_64.rpm
    sudo rpm -i kernel-4.18.0-425.3.1.el8.x86_64.rpm

    echo "Set default kernel"
    sudo grubby --set-default="/boot/vmlinuz-4.18.0-425.3.1.el8.x86_64"

    echo "Prevent yum update to kernel"
    echo 'exclude=redhat-release* kernel* kmod-kvdo*' | sudo tee -a /etc/yum.conf

    echo "Disable SELinux"
    sudo sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

    echo "Enable persistent logging"
    sudo sed -i 's/#Storage.*/Storage=persistent/' /etc/systemd/journald.conf
    
    echo "Enable syslog log rotation"   # per https://lightbitslabs.atlassian.net/wiki/spaces/~625d41c7b8be7c006a43a96c/pages/2640805889/Improve+Log+Rotation+on+Azure+Red+Hat+8.6+8.7+Gen+2+VMs
    sudo sed -i 's|    missingok$|    daily\n    rotate 30\n    compress\n    missingok\n    notifempty|g' /etc/logrotate.d/syslog
    
    echo "Increase partition sizes"     # per https://lightbitslabs.atlassian.net/wiki/spaces/~625d41c7b8be7c006a43a96c/pages/2618753025/Expanding+Space+on+Red+Hat+8.6+Gen+2+Azure+VMs
    sudo lvextend -L+16G /dev/mapper/rootvg-varlv
    sudo lvextend -L+16G /dev/mapper/rootvg-homelv
    sudo lvextend -L+4G /dev/mapper/rootvg-rootlv
    sudo xfs_growfs /var
    sudo xfs_growfs /home
    sudo xfs_growfs /

    echo "Reboot"
    sudo shutdown -r now
}

RunInstall()
{
    InstallSoftware
}

Run()
{
    #Run the program in order
    SetOptions "$@"
    RunInstall
}

Run "$@"
