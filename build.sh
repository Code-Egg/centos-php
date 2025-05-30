#!/bin/bash
#set -x
#set -v
target_server='repo-dev.litespeedtech.com'
prod_server='rpms.litespeedtech.com'
source ./functions.sh #2>/dev/null
EPACE='        '
PHP_V=84
product=$1
platforms=$2
input_archs=$3
lsapiver="8.2"
PUSH_FLAG='OFF'
version=
revision=

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
    echo "${EPACE} ./build.sh [apcu|igbinary|imagick|...|memcached] [8|9|10] [x86_64|aarch64]"
    echo "${EPACE} ./build.sh ioncube 9 x86_64"    
    echo -e "\033[1mOPTIONS\033[0m"
    echow '--version [NUMBER]'
    echo "${EPACE}${EPACE}Specify package version number"    
    echo "${EPACE}${EPACE}Example:./build.sh ioncube 9 x86_64 --version 5.1.24"
    echow '--revision [NUMBER]'
    echo "${EPACE}${EPACE}Specify package revision number"    
    echo "${EPACE}${EPACE}Example:./build.sh ioncube 9 x86_64 --version 5.1.24 --revision 5"
    echow '--push-flag'
    echo "${EPACE}${EPACE}push packages to dev server."    
    echo "${EPACE}${EPACE}Example:./build.sh ioncube 9 x86_64 --push-flag"
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

if [ "${product}" == 'lsphp' ]; then
    product="${product}"${PHP_V}
elif [ "${product}" == 'ioncube' ] || [ "${product}" == 'pear' ]; then
    product="lsphp${PHP_V}-${product}"
else
    product=lsphp${PHP_V}-pecl-"${product}"
fi

if [ -z "${revision}" ]; then
    TMP_DIST=$(echo $dists | awk '{ print $1 }')
    echo ${product} | grep '-' >/dev/null
    if [ $? = 1 ]; then 
        revision=$(curl -isk https://${prod_server}/centos/9/x86_64/RPMS/ | grep ${product}-${version} | \
          sed -nE "s/.*${product}-${version}-([0-9]+)\.el.*/\1/p" | \
          sort -nr | head -n1)
    fi
    if [[ $revision == ?(-)+([[:digit:]]) ]]; then
        revision=$((revision+1))
    else
        echo "$revision is not a number, set value to 1"
        revision=1
    fi      
fi

if [ -z ${input_archs} ]; then
    echo 'input_archs is not found, use default value x86_64'
    archs='x86_64'
else    
    archs=$input_archs
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

check_input
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