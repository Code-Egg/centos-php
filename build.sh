#!/bin/bash
#set -x
#set -v

source ./functions.sh #2>/dev/null
if [ $(id -u) != "0" ]; then
    echo "Error: The user is not root "
    echo "Please run this script as root"
    exit 1
fi

product=$1
version=$2
revision=$3
platforms=$4

if [ "$platforms" == "ALL" ] ; then
        platforms="epel-9-x86_64 epel-8-x86_64 epel-9-aarch64 epel-8-aarch64"
else
        platforms=`echo $platforms | sed s/e8a/epel-8-aarch64/ | sed s/e7a/epel-7-aarch64/ | sed s/e9a/epel-9-aarch64/ | sed s/e9x/epel-9-x86_64/ | sed s/e8x/epel-8-x86_64/ | sed  s/e7x/epel-7-x86_64/ | sed  s/e6x/epel-6-x86_64/ | sed  s/e6i/epel-6-i386/ | sed  s/e5x/epel-5-x86_64/ | sed  s/e5i/epel-5-i386/`
fi

echo "The following platforms are specified:"
echo $platforms
cur_path=$(pwd)
product_dir=${cur_path}/packaging/build/$product
result_dir=${product_dir}/$version-$revision/result

build_dir=$(cur_path)/build
BUILD_SPECS=$(cur_path)/build/SPECS
BUILD_SOURCES=$(cur_path)/build/SOURCES
BUILD_SRPMS=$(cur_path)/build/SRPMS

BUILDER_NAME="LiteSpeedTech"
BUILDER_EMAIL="info@litespeedtech.com"

specify_versions
set_paras

echo " Process start time : "
echo $(date)

if [ -d $result_dir ]; then
    echo
    read -p "The result directory already existing, do you want to clear it? y/n:         " Yes_or_No
    echo
fi

if [ "${Yes_or_No}" == y ]; then
    echo
    echo -e "\x1b[33m Clear the result directory for new build ! \x1b[0m"
    echo
    rm -rf $result_dir/*
fi

mkdir -p $result_dir

for platform in $platforms;
do
    mkdir -p $result_dir/$platform
done

generate_spec
prepare_source
build_rpms

echo
echo -e "\x1b[33m ********* Here is the build result dir content ********* \x1b[0m"
echo
ls -lRX $result_dir
echo
echo -e "\x1b[33m ********* End of building result ********* \x1b[0m"
echo

echo
echo " Process finish time : "
echo $(date)
echo
