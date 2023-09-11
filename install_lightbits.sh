#!/usr/bin/bash
# This script will install Lightbits in the cloud from an installer instance
#
# Updates:
# --------
# 07-Aug-2023 [OE]   added 'generic' node/server option, support now only single-node 4 to 12 ssds, no chrony, data-ips conf for single data interface
#                    added some echo prints (ease debug)
#                    added install for jq (was missing on some vanila's)
#                    added centos ga 3-3-x option (w.o kernel base)
#                    fix docker ansible execution: using 'sudo docker run -i' instead of 'sudo docker run -it"
#                    TODO: to consider add support for dual nodes data interfaces
# 08-Aug-2023 [OE]   add jq install also in CheckVersion
#
INSTALL_LIGHTBITS_VERSION="V1.02"

## GLOBAL VARIABLES ##
LB_JSON="{\"lbVersions\": [
    {
        \"versionName\": \"lightos-3-3-x-ga\",
        \"versionLightApp\": \"light-app-install-environment-v3.3.1~b1334.tgz\",
        \"kernelVersion\": \"\",
        \"kernelLinkBase\": \"\"
    },
    {
        \"versionName\": \"lightos-3-1-2-rhl-86\",
        \"versionLightApp\": \"light-app-install-environment-v3.1.2~b1127.tgz\",
        \"kernelVersion\": \"4.18.0-425.3.1.el8.x86_64\",
        \"kernelLinkBase\": \"https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/Packages/\"
    },
    {
        \"versionName\": \"lightos-3-2-1-rhl-86\",
        \"versionLightApp\": \"light-app-install-environment-v3.2.1~b1252.tgz\",
        \"kernelVersion\": \"4.18.0-425.19.2.el8_7.x86_64\",
        \"kernelLinkBase\": \"https://repo.almalinux.org/almalinux/8.7/BaseOS/x86_64/os/Packages/\"
    },
    {
        \"versionName\": \"lightos-3-3-1-rhl-8\",
        \"versionLightApp\": \"light-app-install-environment-v3.3.1~b1335.tgz\",
        \"kernelVersion\": \"4.18.0-477.13.1.el8_8.x86_64\",
        \"kernelLinkBase\": \"https://repo.almalinux.org/almalinux/8.8/BaseOS/x86_64/os/Packages/\"
    },
    {
        \"versionName\": \"lightos-3-4-1-rhl-8\",
        \"versionLightApp\": \"light-app-install-environment-v3.4.1~b1397.tgz\"
    }
]}"
CURRENT_DIR=`pwd`

# Display help menu
DisplayHelp()
{
    echo "This script will configure the installation and install Lightbits on VMs in the cloud or generic server. $INSTALL_LIGHTBITS_VERSION
   
    Syntax: ${0##*/} [-m|n|i|u|p|k|t|v|c]
    options:                                     example:
    m    Configure mode.                         configure, install
    n    Node type.                              l16s_v3, l32s_v3, l64s_v3, l80s_v3, i3en.6xlarge, i3en.12xlarge, i3en.24xlarge, i3en.metal, i4i.8xlarge, i4i.16xlarge, i4i.32xlarge, i4i.metal, generic
    i    List of server IPs.                     \"10.0.0.1,10.0.0.2,10.0.0.3\"
    u    Username.                               root
    p    Password - use SINGLE quotes ''.        'p@ssword12345!!'
    k    Path to key.                            /home/root/keys/key.pem
    t    Lightbits Repository token.             QWCEWVDASADSSsSD
    v    Lightbits Version.                      lightos-3-1-2-rhl-86, lightos-3-2-1-rhl-86, lightos-3-3-1-rhl-8, lightos-3-4-1-rhl-8
    c    Lightbits Cluster Name.                 aws-cluster-0
    d    Data IPs                                optional to provide data interface ips required for generic node case \"10.0.0.1,10.0.0.2,10.0.0.3\"

    Full Example (Azure with password):
    ${0##*/} -m configure -n l16s_v3 -i \"10.0.0.1,10.0.0.2,10.0.0.3\" -u azureuser -p \'password\' -t QWCEWVDASADSSsSD -v lightos-3-2-1-rhl-86 -c test-cluster
    ${0##*/} -m install -c test-cluster -v lightos-3-2-1-rhl-86

    Full Example (AWS with keys):
    ${0##*/} -m configure -n i3en.6xlarge -i \"10.0.0.1,10.0.0.2,10.0.0.3\" -u ec2-user -k /home/ec2-user/key.pem -t QWCEWVDASADSSsSD -v lightos-3-2-1-rhl-86 -c test-cluster
    ${0##*/} -m install -c test-cluster -v lightos-3-2-1-rhl-86

    Full Example (generic/pre-allocated-lab-servers, with password):
    ${0##*/} -m configure -n generic -i \"rack99-server01,rack99-server02,rack99-server03\" -u azureuser -p \'password\' -t QWCEWVDASADSSsSD -v lightos-3-3-x-ga -c test-cluster -d \"10.109.11.251,10.109.11.252,10.109.11.253\"
    ${0##*/} -m install -c test-cluster -v lightos-3-3-x-ga

    Notes
    For generic server need to provide data ip, only single lb node is created on generic server
"

}

# Get entered options and set them as variables
SetOptions()
{
    # Get and set the options
    local OPTIND
    while getopts ":h:m:n:i:u:p:k:t:v:c:d:" option; do
        case "${option}" in
            h)
                DisplayHelp
                exit;;
            m)
                mode="$OPTARG"
                ;;
            n)
                node="$OPTARG"
                ;;
            i)
                ipList="$OPTARG"
                ;;
            u)
                username="$OPTARG"
                ;;
            p)
                password="$OPTARG"
                ;;
            k)
                keyPath="$OPTARG"
                ;;
            t)
                repoToken="$OPTARG"
                ;;
            v)
                lbVersion="$OPTARG"
                ;;
            c)
                clusterName="$OPTARG"
                ;;
            d)
                dataIPs="$OPTARG"
                ;;
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


    if [ -z "${dataIPs}" ]; then # not provided data ips?
        if [ "${node}" == "generic" ]; then # for generic server must provide dataIPs
            echo "missing dataIPs, must provide dataIPs (-d) for generic servers"
            DisplayHelp
            exit 1
        else # cloud servers, use same data ips as managment ips (ipList)
            dataIPs=${ipList}
        fi
    fi
}

# Configures the installer instance
ConfigureInstaller()
{
    # Create clients file for pssh to use
    CreatePsshClientFile()
    {
        echo "Creating pssh clients file"
        echo "" > "${CURRENT_DIR}/${clusterName}/clients"
        for ip in ${serverIPs[@]}; do
            echo "${username}@${ip}" >> "${CURRENT_DIR}/${clusterName}/clients"
        done
    }

    # Pull lbapp and docker container
    PullInstallerSoftware()
    {
        LB_BUILD=`echo ${LB_JSON} | jq -r '.lbVersions[] | select(.versionName == "'${lbVersion}'") | .versionLightApp'`
        echo "Version=${lbVersion}, Build=${LB_BUILD}"
        
        echo "Logging into docker"
        sudo docker login docker.lightbitslabs.com -u "${lbVersion}" -p "${repoToken}"

        echo "Pulling docker image"
        sudo docker pull docker.lightbitslabs.com/"${lbVersion}"/lb-ansible:4.2.0

        echo "Installing wget"
        sudo yum install -qy wget

        echo "Pull install tarball"
        wget 'https://dl.lightbitslabs.com/'${repoToken}'/'${lbVersion}'/raw/files/'${LB_BUILD}'?accept_eula=1' -O "${CURRENT_DIR}/${clusterName}/${LB_BUILD}"

        echo "Unpack tarball"
        tar -xvf "${CURRENT_DIR}/${clusterName}/${LB_BUILD}" -C "${CURRENT_DIR}/${clusterName}/"
    }

    # Create a working directory based on cluster name
    MakeWorkingDirectories()
    {
        echo "Creating working directory: ${CURRENT_DIR}/${clusterName}"
        mkdir -p "${CURRENT_DIR}/${clusterName}"
        mkdir -p "${CURRENT_DIR}/${clusterName}/lightos-certificates"
    }

    # Installs prerequisite software on the installer
    InstallInstallerSoftware()
    {
        echo "Installing tools"
        sudo yum install jq -y
        sudo yum -qy install epel-release
        sudo yum install -qy yum-utils pssh sshpass

        echo "Add docker repo"
        sudo yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo

        echo "Install docker"
        sudo yum install -qy docker-ce docker-ce-cli containerd.io docker-compose-plugin

        echo "Enable and start docker service"
        sudo systemctl enable docker && sudo systemctl start docker
    }

    InstallInstallerSoftware
    MakeWorkingDirectories
    PullInstallerSoftware
    CreatePsshClientFile
}

# Check cluster name provided
CheckClusterName()
{
    if [ -z "${clusterName}" ]; then
        echo "No cluster name provided!"
        DisplayHelp
        exit 1
    fi
}

# Check that the vm type is within the accepted list
CheckVersion()
{
    echo "Check version..."
    sudo yum install jq -y
    versionList=(`echo ${LB_JSON} | jq -r '.lbVersions[].versionName'`)
    containsVersion=0
    for versionId in "${versionList[@]}"; do
        if [ "${versionId}" = "${lbVersion}" ]; then
            containsVersion=1
        fi
    done
    if [ "${containsVersion}" = 0 ]; then
        echo "Version \"${lbVersion}\" not in accepted list: [${versionList[@]}]!"
        DisplayHelp
        exit 1
    fi

}

# Perform checks on inputs
CheckConfigure()
{
    echo "Check configure..."

    # Check that the vm type is within the accepted list
    CheckVMType()
    {
        nodeList=("l16s_v3" "l32s_v3" "l64s_v3" "l80s_v3" "i3en.6xlarge" "i3en.12xlarge" "i3en.24xlarge" "i3en.metal" "i4i.8xlarge" "i4i.16xlarge" "i4i.32xlarge" "i4i.metal" "generic")
        containsNode=0
        for nodeType in "${nodeList[@]}"; do
            if [ "${nodeType}" = "${node}" ]; then
                containsNode=1
            fi
        done
        if [ "${containsNode}" = 0 ]; then
            echo "Node \"${node}\" not in accepted list: [${nodeList[@]}]!"
            DisplayHelp
            exit 1
        fi

    }

    # Check if a key or password has been provided
    CheckKeyOrPass()
    {
        CopyKey()
        {
            # Move key to keys directory
            keyName="${keyPath##*/}"
            mkdir -p ${CURRENT_DIR}/${clusterName}/keys
            cp -n "${keyPath}" "${CURRENT_DIR}/${clusterName}/keys/${keyName}"
            sudo chmod 400 "${CURRENT_DIR}/${clusterName}/keys/${keyName}"
        }

        useKey=0
        if [ -z "${keyPath}" ] && [ -z "${password}" ]; then
            echo "Please provide either password or key file for destination nodes!"
            DisplayHelp
            exit 1
        fi
        if [ "${keyPath}" ] && [ "${password}" ]; then
            echo "Please provide either password OR key file for destination nodes!"
            DisplayHelp
            exit 1
        fi
        if [ -z "${password}" ]; then
            useKey=1
            if [ ! -f "${keyPath}" ]; then
                echo "Can't find key file, please check the path: ${keyPath} or enter a password!"
                exit 1
            else
                CopyKey
            fi
        fi
    }

    # Check that the username for ssh login has been provided
    CheckUsername()
    {
        if [ -z "${username}" ]; then
            echo "No username provided!"
            DisplayHelp
            exit 1
        fi
    }

    # Check that the repo token has been provided
    CheckToken()
    {
        if [ -z "${repoToken}" ]; then
            echo "No token provided!"
            DisplayHelp
            exit 1
        fi
    }

    # Parse server ips into array
    ParseServerIPs()
    {
        # Check contains values
        if [ -z "${ipList}" ]; then
            echo "No Server IPs found!"
            DisplayHelp
            exit 1
        fi

        # Convert string into array
        serverIPs=($(echo "${ipList}" | tr ',' '\n'))
        # Check min 3 nodes
        if [[ "${#serverIPs[@]}" -lt 3 ]]; then
            echo "Minimum 3 nodes required, ${#serverIPs[@]} provided: ${ipList}"
            exit 1
        fi
        # Check no duplicate IPs provided
        uniqueNum=$(printf '%s\n' "${serverIPs[@]}"|awk '!($0 in seen){seen[$0];c++} END {print c}')
        if [[ "${uniqueNum}" != "${#serverIPs[@]}" ]]; then
            echo "Duplicate values found in ${ipList}, please remove them!"
            exit 1
        fi

        # Check max 16 nodes ...[OE] i removed to allow larger installations
        #if [[ "${#serverIPs[@]}" -gt 16 ]]; then
        #    echo "Maximum 16 nodes required, ${#serverIPs[@]} provided: ${ipList}"
        #    exit 1
        #fi

        if [ -z "${dataIPs}" ]; then
            echo "No Server data IPs found!"
            DisplayHelp
            exit 1
        fi

        # Convert string into array
        serverDataIPs=($(echo "${dataIPs}" | tr ',' '\n'))
        # Check min 3 nodes
        if [[ "${#serverDataIPs[@]}" -lt 3 ]]; then
            echo "Minimum 3 nodes data ip required, ${#serverDataIPs[@]} provided: ${dataIPs}"
            exit 1
        fi
        # Check no duplicate IPs provided
        uniqueNum=$(printf '%s\n' "${serverDataIPs[@]}"|awk '!($0 in seen){seen[$0];c++} END {print c}')
        if [[ "${uniqueNum}" != "${#serverDataIPs[@]}" ]]; then
            echo "Duplicate values found in ${dataIPs}, please remove them!"
            exit 1
        fi
    }

    CheckVMType
    CheckClusterName
    CheckKeyOrPass
    CheckUsername
    CheckToken
    CheckVersion
    ParseServerIPs
}

# Prepare the target hosts
PrepTargets()
{
    echo "Preparing targets: ${ipList}"

    userspace=`echo ${LB_JSON} | jq -e '.lbVersions[] | select(.versionName == "'${lbVersion}'") | .kernelLinkBase'`

    if [[ ${userspace} -eq null ]]; then # Use a different config for userspace
        echo "Userspace release"
        read -r -d '' targetPrepCommands << EOF
sudo yum install -qy wget iptables

echo 'exclude=redhat-release* kernel* kmod-kvdo*' | sudo tee -a /etc/yum.conf

sudo sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

sudo sed -i 's/#Storage.*/Storage=persistent/' /etc/systemd/journald.conf

sudo sed -i 's|    missingok$|    daily\n    rotate 30\n    compress\n    missingok\n    notifempty|g' /etc/logrotate.d/syslog

EOF
    else # Install kernel etc.
        echo "Kernelspace release"
        lbKernelBaseURL=`echo ${LB_JSON} | jq -r '.lbVersions[] | select(.versionName == "'${lbVersion}'") | .kernelLinkBase'`
        lbKernelVersion=`echo ${LB_JSON} | jq -r '.lbVersions[] | select(.versionName == "'${lbVersion}'") | .kernelVersion'`
        read -r -d '' targetPrepCommands << EOF
sudo yum install -qy wget iptables

wget "${lbKernelBaseURL}kernel-core-${lbKernelVersion}.rpm"
wget "${lbKernelBaseURL}kernel-modules-${lbKernelVersion}.rpm"
wget "${lbKernelBaseURL}kernel-${lbKernelVersion}.rpm"

sudo rpm -i "kernel-core-${lbKernelVersion}.rpm"
sudo rpm -i "kernel-modules-${lbKernelVersion}.rpm"
sudo rpm -i "kernel-${lbKernelVersion}.rpm"

sudo grubby --set-default="/boot/vmlinuz-${lbKernelVersion}"

echo 'exclude=redhat-release* kernel* kmod-kvdo*' | sudo tee -a /etc/yum.conf

sudo sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

sudo sed -i 's/#Storage.*/Storage=persistent/' /etc/systemd/journald.conf

sudo sed -i 's|    missingok$|    daily\n    rotate 30\n    compress\n    missingok\n    notifempty|g' /etc/logrotate.d/syslog

# Enable unsigned kernel modules
# Get line
LINE=`grep "GRUB_CMDLINE_LINUX" /etc/default/grub`
MODULE_ADD="module.sig_enforce=0"
# Get entries
TRIMMED=`echo \$LINE | sed -n -e 's/^.*GRUB_CMDLINE_LINUX=//p' | tr -d '\"'`
if [[ \${TRIMMED} == *"\${MODULE_ADD}"* ]]; then
    # Do nothing
    echo "No change."
else
    # Replace line
    NEW_LINE="GRUB_CMDLINE_LINUX=\"${TRIMMED} ${MODULE_ADD}\""
    sudo sed -i "s/.*${LINE}.*/${NEW_LINE}/" /etc/default/grub
fi

echo "Reboot"
sudo shutdown -r now
EOF
    fi
    
    if [ ${useKey} == 0 ]; then
        echo "Using Password and running target configuration > sshpass -p ${password} pssh -h ${CURRENT_DIR}/${clusterName}/clients -x -o StrictHostKeyChecking=false -l root -A -t 900 -i ${targetPrepCommands}"
        sshpass -p ${password} pssh -h "${CURRENT_DIR}/${clusterName}/clients" -x "-o StrictHostKeyChecking=false" -l root -A -t 900 -i "${targetPrepCommands}"
    else
        echo "Using key and running target configuration > sudo pssh -h ${CURRENT_DIR}/${clusterName}/clients -x -i ${CURRENT_DIR}/${clusterName}/keys/${keyName} -o StrictHostKeyChecking=false -t 900 -i ${targetPrepCommands}"
        sudo pssh -h "${CURRENT_DIR}/${clusterName}/clients" -x "-i ${CURRENT_DIR}/${clusterName}/keys/${keyName} -o StrictHostKeyChecking=false" -t 900 -i "${targetPrepCommands}"
    fi
}

# Prepare ansible scripts
PrepAnsible()
{
    # Create a working directory inside ansible to store cluster information
    CreateAnsibleDirectories()
    {
        mkdir -p ${CURRENT_DIR}/${clusterName}/ansible/inventories/${clusterName}
        mkdir -p ${CURRENT_DIR}/${clusterName}/ansible/inventories/${clusterName}/host_vars
        mkdir -p ${CURRENT_DIR}/${clusterName}/ansible/inventories/${clusterName}/group_vars
    }

    # Iterate through the server array and create the hosts file
    CreateHostsFile()
    {
        serverCount=0
        hostsIPSection=""
        durosnodesSection="[duros_nodes]
"
        etcdSection="[etcd]
"
        initiatorsSection="[initiators]
"
        # Create strings
        for host in "${serverIPs[@]}"; do
            serverName="server${serverCount}"
            if [ "${useKey}" -eq 1 ]; then
                hostsIPSection+="${serverName} ansible_host=${host} ansible_connection=ssh ansible_ssh_private_key_file=/lb_install/keys/${keyName} ansible_ssh_user=${username} ansible_become_user=root"
                hostsIPSection+=$'\n'
            else
                hostsIPSection+="${serverName} ansible_host=${host} ansible_connection=ssh ansible_ssh_user=${username} ansible_ssh_pass=${password} ansible_become_user=root"
                hostsIPSection+=$'\n'
            fi
            durosnodesSection+="${serverName}"
            durosnodesSection+=$'\n'
            etcdSection+="${serverName}"
            etcdSection+=$'\n'
            serverCount=$((serverCount+1))
        done

        durosnodesVarsSection="[duros_nodes:vars]
local_repo_base_url=https://dl.lightbitslabs.com/${repoToken}/${lbVersion}/rpm/el/8/\$basearch
cluster_identifier=ae7bdeef-897e-4c5b-abef-20234abf21bf
auto_reboot=false
"

        # Write output
        tee ${CURRENT_DIR}/${clusterName}/ansible/inventories/${clusterName}/hosts > /dev/null << EOL
${hostsIPSection}
${durosnodesSection}
${durosnodesVarsSection}
${etcdSection}
${initiatorsSection}
EOL
    }

    # Create a single server file from input [serverName, serverAddress]
    CreateServerFile()
    {
        if [ "${noDisks}" -eq 0 ]; then # generic server
            initialDeviceCount="4"
            maxDeviceCount="12"
            echo "[OE] using generic server: initialDeviceCount=${initialDeviceCount} , maxDeviceCount=${maxDeviceCount}"
        else
            initialDeviceCount=${noDisks}
            maxDeviceCount=${noDisks}
        fi
        serverName=$1
        serverAddress=$2
        fileContent="
---
name: ${serverName}
nodes:
-   instanceID: 0
    data_ip: ${serverAddress}
    failure_domains:
    - ${serverName}
    ec_enabled: false
    lightfieldMode: SW_LF
    storageDeviceLayout:
      initialDeviceCount: ${initialDeviceCount}
      maxDeviceCount: ${maxDeviceCount}
      allowCrossNumaDevices: true
      deviceMatchers:
#      - model =~ ".*"
        - partition == false
        - size >= gib(300)
#      - name =~ "nvme0n1"
"   
    tee ${CURRENT_DIR}/${clusterName}/ansible/inventories/${clusterName}/host_vars/${serverName}.yml > /dev/null << EOL
${fileContent}
EOL
    }

    # Iterate through the server array and create .yml files for each server
    CreateAllServerFiles()
    {
        # Calculate number of disks based on instance type
        CalculateNoDisks()
        {
            case "${node}" in
                    generic)
                        noDisks=0
                        ;;
                    l16s_v3)
                        noDisks=2
                        ;;
                    l32s_v3)
                        noDisks=4
                        ;;
                    l64s_v3)
                        noDisks=8
                        ;;
                    l80s_v3)
                        noDisks=10
                        ;;
                    i3en.6xlarge)
                        noDisks=2
                        ;;
                    i3en.12xlarge)
                        noDisks=4
                        ;;
                    i3en.24xlarge)
                        noDisks=8
                        ;;
                    i3en.metal)
                        noDisks=8
                        ;;
                    i4i.8xlarge)
                        noDisks=2
                        ;;
                    i4i.16xlarge)
                        noDisks=4
                        ;;
                    i4i.32xlarge)
                        noDisks=8
                        ;;
                    i4i.metal)
                        noDisks=8
                        ;;
                esac
        }
        CalculateNoDisks
        serverCount=0
        for host in "${serverDataIPs[@]}"; do
            CreateServerFile "server${serverCount}" "${host}"
            serverCount=$((serverCount+1))
        done
    }

    CreateGroupVars()
    {

        if [ "${node}" == "generic" ]; then # ...do not use chrony

        # Create the all.yml file within the group_vars directory and configure for generic/on-prem
        tee ${CURRENT_DIR}/${clusterName}/ansible/inventories/${clusterName}/group_vars/all.yml > /dev/null << EOL
---
use_lightos_kernel: false
enable_iptables: false
persistent_memory: false
start_discovery_service_retries: 5
#nvme_subsystem_nqn_suffix: "some_suffix"
#ntp_enabled: true
#chrony_enabled: true
#ntp_manage_config: true
#ntp_servers:
#- 169.254.169.123
#  - "0{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"
#  - "1{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"
#  - "2{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"
#  - "3{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"

#ntp_version: "ntp-4.2.6p5-29.el7.centos.x86_64"

#ntp_packages:
#    - "autogen-libopts*.rpm"
#    - "ntpdate*.rpm"
#    - "ntp*.rpm"
EOL

        else

        # Create the all.yml file within the group_vars directory and configure for cloud
        tee ${CURRENT_DIR}/${clusterName}/ansible/inventories/${clusterName}/group_vars/all.yml > /dev/null << EOL
---
use_lightos_kernel: false
enable_iptables: false
persistent_memory: false
start_discovery_service_retries: 5
#nvme_subsystem_nqn_suffix: "some_suffix"
#ntp_enabled: true
chrony_enabled: true
#ntp_manage_config: true
#ntp_servers:
#- 169.254.169.123
#  - "0{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"
#  - "1{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"
#  - "2{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"
#  - "3{{ '.' + ntp_area if ntp_area else '' }}.pool.ntp.org iburst"

#ntp_version: "ntp-4.2.6p5-29.el7.centos.x86_64"

#ntp_packages:
#    - "autogen-libopts*.rpm"
#    - "ntpdate*.rpm"
#    - "ntp*.rpm"
EOL

    fi

    }

    EditAnsible()
    {
        # Edit the generate_configuration_files.yml file to trick ansible into treating an Azure VM like a bare metal machine
        sudo sed -i "s/datapath_config_folder: 'virtual-datapath-templates'/datapath_config_folder: 'physical-datapath-templates'/" ${CURRENT_DIR}/${clusterName}/roles/install-lightos/tasks/generate_configuration_files.yml

        # Edit the jinja files to set min_replica to 1
        sudo sed -i 's/^minReplicasCount: {{ 1 if use_pmem else 2 }}*$/minReplicasCount: 1/' ${CURRENT_DIR}/${clusterName}/roles/install-lightos/templates/management-templates/cluster-manager.yaml.j2
        sudo sed -i 's/^minReplicasCount: {{ 1 if use_pmem else 2 }}*$/minReplicasCount: 1/' ${CURRENT_DIR}/${clusterName}/roles/install-lightos/templates/management-templates/api-service.yaml.j2
    }

    CreateAnsibleDirectories
    CreateHostsFile
    CreateAllServerFiles
    CreateGroupVars
    EditAnsible
}

# Run program in configure mode
RunConfigure()
{
    echo "#############"
    echo "Run Configure"
    echo "#############"
    CheckConfigure
    ConfigureInstaller
    PrepTargets
    PrepAnsible
}

RunAnsibleInstall()
{
    echo "Do some cleanups..."
    # Clean up any old certs and JWTs
    sudo rm -f ${CURRENT_DIR}/${clusterName}/lightos_jwt
    sudo rm -f ${CURRENT_DIR}/${clusterName}/lightos_default_admin_jwt
    sudo rm -rf ${CURRENT_DIR}/${clusterName}/lightos-certificates

    # Run ansible
    echo "Run ansible with: docker run -i ..."
    sudo docker run -i --rm --net=host \
        -v ${CURRENT_DIR}/${clusterName}/lightos-certificates:/lightos-certificates \
        -v ${CURRENT_DIR}/${clusterName}:/lb_install \
        -w /lb_install \
        docker.lightbitslabs.com/${lbVersion}/lb-ansible:4.2.0 \
        sh -c 'ansible-playbook \
            -e ANSIBLE_LOG_PATH=/lb_install/ansible.log \
            -e system_jwt_path=/lb_install/lightos_jwt \
            -e lightos_default_admin_jwt=/lb_install/lightos_default_admin_jwt \
            -e certificates_directory=/lightos-certificates \
            -i /lb_install/ansible/inventories/"'${clusterName}'"/hosts \
            /lb_install/playbooks/deploy-lightos.yml -vvv'
}

RunInstall()
{
    # Run program in install mode
    echo "#############"
    echo "Run Install"
    echo "#############"
    CheckClusterName
    CheckVersion
    RunAnsibleInstall
}

# Check program mode
RunMode()
{
    # Check that a supported mode has been provided
    CheckMode()
    {
        modeList=("configure" "install")
        containsMode=0
        for modeType in "${modeList[@]}"; do
            if [ "${modeType}" = "${mode}" ]; then
                containsMode=1
            fi
        done
        if [ "${containsMode}" = 0 ]; then
            echo "Mode \"${mode}\" not in accepted list: [${modeList[@]}]!"
            DisplayHelp
            exit 1
        fi

    }

    CheckMode
    case "${mode}" in
            configure)
                RunConfigure
                ;;
            install)
                RunInstall
                ;;
        esac
}

#Run the program in order
Run()
{
    SetOptions "$@"
    RunMode
}

Run "$@"
