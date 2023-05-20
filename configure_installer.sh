#!/usr/bin/bash
# This script will configure a Lightbits manual installer VM ready to install Lightbits

#### GLOBAL VARIABLES ####
LB_VERSION="lightos-3-1-2-rhl-86"
LB_BUILD="light-app-install-environment-v3.1.2~b1127.tgz"
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

DisplayHelp()
{
    # Display help menu
    echo "This script will configure the installer VM ready to install Lightbits
   
    Syntax: $FUNCNAME [-h|v|t|b]
    options:                                    example:
    h   Display This Help.
    v   Lightbits Version.                      lightos-3-1-2-rhl-86 (Default)
    t   Lightbits Repository token.             QWCEWVDASADSSsSD (Required)

"
}

# Get entered options and set them as variables
SetOptions()
{
    # Get and set the options
    local OPTIND
    while getopts ":h:v:t:" option; do
        case "${option}" in
            h)
                DisplayHelp
                exit;;
            v)
                INS_VERSION="$OPTARG"
                ;;
            t)
                LB_TOKEN="$OPTARG"
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

CheckToken()
{
    # Check that the token has been provided
    if [ -z "${LB_TOKEN}" ]; then
        echo "No token provided!"
        DisplayHelp
        exit 1
    fi
}

CheckVersion()
{
    # Check that the version has been provided
    if [ -z "${INS_VERSION}" ]; then
        echo "No version provided, using default: ${LB_VERSION}!"
    else
        echo "Using Lightbits version ${INS_VERSION}!"
        LB_VERSION="${INS_VERSION}"
    fi
}

InstallSoftware()
{
    echo "Installing tools"
    sudo yum install -y jq
    
    echo "Uninstalling docker"
    sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  podman \
                  runc
    
    echo "Install Yum Utils"
    sudo yum install -y yum-utils

    echo "Add docker repo"
    sudo yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo

    echo "Install docker"
    sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin

    echo "Enable and start docker service"
    sudo systemctl enable docker && sudo systemctl start docker
}

PullInstallSoftware()
{
    LB_BUILD=`echo ${LB_JSON} | jq -r '.lbVersions[] | select(.versionName == "'${LB_VERSION}'") | .versionLightApp'`
    echo "Version=${LB_VERSION}, Build=${LB_BUILD}"
    
    echo "Logging into docker"
    sudo docker login docker.lightbitslabs.com -u "${LB_VERSION}" -p "${LB_TOKEN}"

    echo "Pulling docker image"
    sudo docker pull docker.lightbitslabs.com/"${LB_VERSION}"/lb-ansible

    echo "Installing wget"
    sudo yum install wget

    echo "Pull install tarball"
    wget 'https://dl.lightbitslabs.com/"${LB_TOKEN}"/"${LB_VERSION}"/raw/files/"${LB_BUILD}"?accept_eula=1' -O "${LB_BUILD}"

    echo "Unpack tarball"
    tar -xvf "${LB_BUILD}"
}

CheckInputs()
{
    CheckToken
    CheckVersion
    CheckBuild
}

RunInstall()
{
    InstallSoftware
}

Run()
{
    #Run the program in order
    SetOptions "$@"
    CheckInputs
    RunInstall
}

Run "$@"