#!/usr/bin/bash
# Script to help deploy Lightbits manually on cloud VMs

#### GLOBAL VARIABLES ####
LB_VERSION="lightos-3-1-2-rhl-86"

DisplayHelp()
{
    # Display help menu
    echo "This script will configure the installation and install Lightbits on VMs in the cloud.
   
    Syntax: $FUNCNAME [-m|t|i|au|ap|ak]
    options:                                     example:
    m     Configure mode.                        configure, display, install
    n     Node type.                             l16s_v3, l32s_v3, l64s_v3, l80s_v3
    i     List of server IPs.                    \"10.0.0.1,10.0.0.2,10.0.0.3\"
    u    Username.                               root
    p    Password - use SINGLE quotes ''.        'p@ssword12345!!'
    k    Path to key.                            /home/root/keys/key.pem
    t    Lightbits Repository token.             QWCEWVDASADSSsSD

"
}

# Get entered options and set them as variables
SetOptions()
{
    # Get and set the options
    local OPTIND
    while getopts ":h:m:n:i:u:p:k:t:" option; do
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

CheckMode()
{
    # Check that a supported mode has been provided
    modeList=("configure" "display" "install")
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

CheckVMType()
{
    # Check that the vm type is within the accepted list
    nodeList=("l16s_v3" "l32s_v3" "l64s_v3" "l80s_v3")
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

CheckCurrentDirectory()
{
    # Check that the script is being run in the same directory as the ansible.cfg
    if [ ! -f ansible.cfg ]; then
        echo "Can't find ansible.cfg file, please ensure you're running from the correct directory!"
        exit 1
    fi
}

CheckUsername()
{
    # Check that the username for ssh login has been provided
    if [ -z "${username}" ]; then
        echo "No username provided!"
        DisplayHelp
        exit 1
    fi
}

CheckKeyOrPass()
{
    # Check if a key or password has been provided and set the "useKey" param if a key is used
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

CheckToken()
{
    # Check that the repo token has been provided
    if [ -z "${repoToken}" ]; then
        echo "No token provided!"
        DisplayHelp
        exit 1
    fi
}

Checks()
{
    # Perform checks on inputs
    CheckVMType
    CheckCurrentDirectory
    CheckKeyOrPass
    CheckUsername
    CheckToken
}

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

CopyKey()
{
    # Move key to keys directory
    keyName="${keyPath##*/}"
    mkdir -p ./keys
    cp -n "${keyPath}" ./keys/"${keyName}"
}

CreateHostsFile()
{
    # Iterate through the server array and create the hosts file
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

    # Create backup
    cp ./ansible/inventories/cluster_example/hosts ./ansible/inventories/cluster_example/hosts.bak
    # Write output
    tee -a ./ansible/inventories/cluster_example/hosts > /dev/null << EOL
${hostsIPSection}
${durosnodesSection}
${durosnodesVarsSection}
${etcdSection}
${initiatorsSection}
EOL
}

CalculateNoDisks()
{
    # Calculate number of disks based on instance type
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
        esac
}

CreateServerFile()
{
    # Create a single server file from input [serverName, serverAddress]
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
    tee -a ./ansible/inventories/cluster_example/host_vars/${serverName}.yml > /dev/null << EOL
${fileContent}
EOL
}

CreateAllServerFiles()
{
    # Iterate through the server array and create .yml files for each server
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
    tee -a ./ansible/inventories/cluster_example/group_vars/all.yml > /dev/null << EOL
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
    sed -i 's/^datapath_config_folder: .*$/datapath_config_folder: "physical-datapath-templates"/' ./roles/install-lightos/tasks/generate_configuration_files.yml
}

RunAnsible()
{
    mkdir -p /opt/lightos-certificates
    docker run -it --rm --net=host \
        -v `pwd`/lightos-certificates/:/lightos-certificates \
        -v `pwd`/:/lb_install \
        -w /lb_install \
        docker.lightbitslabs.com/${LB_VERSION}/lb-ansible:4.2.0 \
        sh -c 'ansible-playbook \
            -e ANSIBLE_LOG_PATH=/lb_install/ansible.log \
            -e system_jwt_path=/lb_install/lightos_jwt \
            -e lightos_default_admin_jwt=/lb_install/lightos_default_admin_jwt \
            -e certificates_directory=/lightos-certificates \
            -i /lb_install/ansible/inventories/cluster_example/hosts \
            /lb_install/playbooks/deploy-lightos.yml -vvv'
}

RunInstall()
{
    # Run program in install mode
    echo "#############"
    echo "Run Install"
    echo "#############"
    RunAnsible
}

RunDisplay()
{
    # Run program in display mode
    echo "#############"
    echo "Run Display"
    echo "#############"
    exit 1
}

RunConfigure()
{
    # Run program in configure mode
    echo "#############"
    echo "Run Configure"
    echo "#############"
    Checks
    ParseServerIPs
    CreateHostsFile
    CreateAllServerFiles
    CreateGroupVars
    EditAnsible
}

RunMode()
{
    # Check program mode
    CheckMode
    case "${mode}" in
            configure)
                RunConfigure
                ;;
            display)
                RunDisplay
                ;;
            install)
                RunInstall
                ;;
        esac
}

Run()
{
    #Run the program in order
    SetOptions "$@"
    RunMode
}

Run "$@"
