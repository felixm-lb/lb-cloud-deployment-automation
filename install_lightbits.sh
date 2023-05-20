#!/usr/bin/bash
# This script will install Lightbits in the cloud from an installer instance

## GLOBAL VARIABLES ##
LB_JSON="{\"lbVersions\": [
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
    }
]}"
CURRENT_DIR=`pwd`

# Display help menu
DisplayHelp()
{
    echo "This script will configure the installation and install Lightbits on VMs in the cloud.
   
    Syntax: ${0##*/} [-m|n|i|u|p|k|t|v|c]
    options:                                     example:
    m    Configure mode.                         configure, install
    n    Node type.                              l16s_v3, l32s_v3, l64s_v3, l80s_v3, i3en.6xlarge, i3en.12xlarge, i3en.24xlarge, i3en.metal, i4i.8xlarge, i4i.16xlarge, i4i.32xlarge, i4i.metal
    i    List of server IPs.                     \"10.0.0.1,10.0.0.2,10.0.0.3\"
    u    Username.                               root
    p    Password - use SINGLE quotes ''.        'p@ssword12345!!'
    k    Path to key.                            /home/root/keys/key.pem
    t    Lightbits Repository token.             QWCEWVDASADSSsSD
    v    Lightbits Version.                      lightos-3-2-1-rhl-86
    c    Lightbits Cluster Name.                 aws-cluster-0

    Full Example (Azure with password):
    ${0##*/} -m configure -n l16s_v3 -i \"10.0.0.1,10.0.0.2,10.0.0.3\" -u azureuser -p \'password\' -t QWCEWVDASADSSsSD -v lightos-3-2-1-rhl-86 -c test-cluster
    ${0##*/} -m install -c test-cluster -v lightos-3-2-1-rhl-86

    Full Example (AWS with keys):
    ${0##*/} -m configure -n i3en.6xlarge -i \"10.0.0.1,10.0.0.2,10.0.0.3\" -u ec2-user -k /home/ec2-user/key.pem -t QWCEWVDASADSSsSD -v lightos-3-2-1-rhl-86 -c test-cluster
    ${0##*/} -m install -c test-cluster -v lightos-3-2-1-rhl-86

"
}

# Get entered options and set them as variables
SetOptions()
{
    # Get and set the options
    local OPTIND
    while getopts ":h:m:n:i:u:p:k:t:v:c:" option; do
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
        sudo yum -qy install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
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
    sudo yum install -qy jq

    # Check that the vm type is within the accepted list
    CheckVMType()
    {
        nodeList=("l16s_v3" "l32s_v3" "l64s_v3" "l80s_v3" "i3en.6xlarge" "i3en.12xlarge" "i3en.24xlarge" "i3en.metal" "i4i.8xlarge" "i4i.16xlarge" "i4i.32xlarge" "i4i.metal")
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
        # Check max 16 nodes
        if [[ "${#serverIPs[@]}" -gt 16 ]]; then
            echo "Maximum 16 nodes required, ${#serverIPs[@]} provided: ${ipList}"
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
    lbKernelBaseURL=`echo ${LB_JSON} | jq -r '.lbVersions[] | select(.versionName == "'${lbVersion}'") | .kernelLinkBase'`
    lbKernelVersion=`echo ${LB_JSON} | jq -r '.lbVersions[] | select(.versionName == "'${lbVersion}'") | .kernelVersion'`
    read -r -d '' targetPrepCommands << EOF
sudo yum install -qy wget

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
    if [ ${useKey} == 0 ]; then
        echo "Using Password and running target configuration!"
        sshpass -p ${password} pssh -h "${CURRENT_DIR}/${clusterName}/clients" -x "-o StrictHostKeyChecking=false" -l root -A -t 900 -i "${targetPrepCommands}"
    else
        echo "Using key and running target configuration!"
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
        durosnodesSection="[durosnodes]
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
local_repo_base_url=https://dl.lightbitslabs.com/${repoToken}/${LB_VERSION}/rpm/el/8/$basearch
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
      initialDeviceCount: ${noDisks}
      maxDeviceCount: ${noDisks}
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
        for host in "${serverIPs[@]}"; do
            CreateServerFile "server${serverCount}" "${host}"
            serverCount=$((serverCount+1))
        done
    }

    CreateGroupVars()
    {
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
    }

    EditAnsible()
    {
        # Edit the generate_configuration_files.yml file to trick ansible into treating an Azure VM like a bare metal machine
        sed -i 's/^datapath_config_folder: .*$/datapath_config_folder: "physical-datapath-templates"/' ${CURRENT_DIR}/${clusterName}/roles/install-lightos/tasks/generate_configuration_files.yml

        # Edit the jinja files to set min_replica to 1
        sed -i 's/^minReplicasCount: {{ 1 if use_pmem else 2 }}*$/minReplicasCount: 1/' test-cluster/roles/install-lightos/templates/management-templates/cluster-manager.yaml.j2
        sed -i 's/^minReplicasCount: {{ 1 if use_pmem else 2 }}*$/minReplicasCount: 1/' test-cluster/roles/install-lightos/templates/management-templates/api-service.yaml.j2
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

RunAnsible()
{
    sudo docker run -it --rm --net=host \
        -v ${CURRENT_DIR}/${clusterName}/lightos-certificates:/lightos-certificates \
        -v ${CURRENT_DIR}/${clusterName}:/lb_install \
        -w /lb_install \
        docker.lightbitslabs.com/${lbVersion}/lb-ansible:4.2.0 \
        sh -c 'ansible-playbook \
            -e ANSIBLE_LOG_PATH=/lb_install/ansible.log \
            -e system_jwt_path=/lb_install/lightos_jwt \
            -e lightos_default_admin_jwt=/lb_install/lightos_default_admin_jwt \
            -e certificates_directory=/lightos-certificates \
            -i /lb_install/ansible/inventories/'${clusterName}'/hosts \
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
    RunAnsible
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