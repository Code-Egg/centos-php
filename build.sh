#!/bin/bash
#set -x
#set -v
target_server='repo-dev.litespeedtech.com'
prod_server='rpms.litespeedtech.com'
EPACE='        '
PHP_V=84
product=$1
version=$2
revision=$3
platforms=$4
lsapiver="8.2"
PUSH_FLAG='OFF'

source ./functions.sh #2>/dev/null
if [ $(id -u) != "0" ]; then
    echo "Error: The user is not root "
    echo "Please run this script as root"
    exit 1
fi
echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}
show_help()
{
    echo -e "\033[1mExamples\033[0m"
    echo "${EPACE} ./build.sh [apcu|igbinary|imagick|...|memcached] [e9x|e8x|e9a|e8a] [amd64|arm64]"
    echo "${EPACE} ./build.sh ioncube bookworm amd64"    
    echo -e "\033[1mOPTIONS\033[0m"
    echow '--version [NUMBER]'
    echo "${EPACE}${EPACE}Specify package version number"    
    echo "${EPACE}${EPACE}Example:./build.sh apcu noble amd64 --version 5.1.24"
    echow '--revision [NUMBER]'
    echo "${EPACE}${EPACE}Specify package revision number"    
    echo "${EPACE}${EPACE}Example:./build.sh apcu noble amd64 --version 5.1.24 --revision 5"
    echow '--push-flag'
    echo "${EPACE}${EPACE}push packages to dev server."    
    echo "${EPACE}${EPACE}Example:./build.sh apcu noble amd64 --push-flag"
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit."
    exit 0
}
if [ -z "${1}" ]; then
    show_help
fi

if [ -z "${version}" ]; then
    version="$(grep ${product}= VERSION.txt | awk -F '=' '{print $2}')"
fi

if [ -z "${revision}" ]; then
    TMP_DIST=$(echo $dists | awk '{ print $1 }')
    echo ${product} | grep '-' >/dev/null
    if [ $? = 1 ]; then 
        revision=$(curl -isk https://${prod_server}/centos/9/x86_64/RPMS/ | grep ${product}-${version} \
          | awk -F '-' '{print $3}' | awk -F '+' '{print $1}' | tail -1)
    else
        revision=$(curl -isk https://${prod_server}/centos/9/x86_64/RPMS/  | grep ${product}-${version} \
          | awk -F '-' '{print $4}' | awk -F '+' '{print $1}' | tail -1)      
    fi      
    if [[ $revision == ?(-)+([[:digit:]]) ]]; then
        revision=$((revision+1))
    else
        echo "$revision is not a number, set value to 1"
        revision=1
    fi      
fi

while [ ! -z "${1}" ]; do
    case $1 in
        --version) shift
            version="${1}"
                ;;
        --revision) shift
            revision="${1}"
                ;;
        --push | --push-flag)
            PUSH_FLAG='ON'
                ;;
        -[hH] | --help)
            show_help
                ;;           
    esac
    shift
done

set_paras
set_build_dir
generate_spec
prepare_source
build_rpms
list_packages
if [ ${PUSH_FLAG} = 'ON' ]; then
    upload_to_server
    gen_dev_release
fi