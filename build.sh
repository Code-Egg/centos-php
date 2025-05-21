#!/bin/bash
#set -x
#set -v

usage(){
        echo
        echo -e "\x1b[33m         Usage: $0 product version build platform (no)build (no)push (no)sync\x1b[0m"
        echo -e "\x1b[33m               platform is double quoted string specifying the platforms \x1b[0m"
        echo -e "\x1b[33m               recognized platforms: ALL e7x e6x e6i e5x e5i \x1b[0m"
        echo -e "\x1b[33m       build - create spec, download source, generate rpms \x1b[0m"
        echo -e "\x1b[33m       push - push the rpms in build folder to localtest server, \x1b[0m"
        echo -e "\x1b[33m                       sign rpms and then push to staging server \x1b[0m"
        echo -e "\x1b[33m       sync - simulate the sync process to production server, \x1b[0m"
        echo -e "\x1b[33m                       print file change list, but do not do real sync \x1b[0m"
        echo
        exit 1
}

[[ $# -lt 6 ]] && usage


# Check if user is root
if [ $(id -u) == "0" ]; then
        echo
        echo -e "\x1b[33m Error: You must log in as gwang to run mock used for rpm build \x1b[0m"
        echo
        exit 1
fi


product=$1
version=$2
revision=$3
platforms=$4
build_flag=$5
push_flag=$6
sync_flag=$7
edge_flag=$8

if [[ $product == *mysql56 ]]; then # for lsphp5*-mysql56
        mocksuffix="-op"
elif [[ $product == ea-* ]]; then
        mocksuffix="-ea"
else
        mocksuffix=""
fi


if [ "x$platforms" == "xALL" ] ; then
        #platforms="epel-7-x86_64 epel-6-x86_64 epel-6-i386 epel-5-x86_64 epel-5-i386"
        #platforms="epel-9-x86_64 epel-8-x86_64 epel-7-x86_64 epel-9-aarch64 epel-8-aarch64"
        platforms="epel-9-x86_64 epel-8-x86_64 epel-9-aarch64 epel-8-aarch64"
else
        platforms=`echo $platforms | sed s/e8a/epel-8-aarch64/ | sed s/e7a/epel-7-aarch64/ | sed s/e9a/epel-9-aarch64/ | sed s/e9x/epel-9-x86_64/ | sed s/e8x/epel-8-x86_64/ | sed  s/e7x/epel-7-x86_64/ | sed  s/e6x/epel-6-x86_64/ | sed  s/e6i/epel-6-i386/ | sed  s/e5x/epel-5-x86_64/ | sed  s/e5i/epel-5-i386/`
fi

echo "The following platforms are specified:"
echo $platforms

product_dir=/home/gwang/packaging/build/$product
result_dir=/home/gwang/packaging/build/$product/$version-$revision/result



#build_dir=/home/gwang/packaging/build/$product/$version-$revision
build_dir=/home/gwang/rpmbuild
RPMBUILD_SPECS=/home/gwang/rpmbuild/SPECS
RPMBUILD_SOURCES=/home/gwang/rpmbuild/SOURCES
RPMBUILD_SRPMS=/home/gwang/rpmbuild/SRPMS

BUILDER_NAME="LiteSpeedTech"
BUILDER_EMAIL="info@litespeedtech.com"

. ./functions.sh 2>/dev/null
. ./.PSWD 2>/dev/null

specify_versions
set_paras


echo " Process start time : "
echo $(date)


if [ "x$build_flag" == "xbuild" ]; then


        if [ -d $result_dir ]; then
            echo
            read -p "The result directory already existing, do you want to clear it? y/n:         " Yes_or_No
            echo
        fi

        if [ x$Yes_or_No == xy ]; then
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
        #if [[ ${RET} != '0' ]]; then
        #       build_rpms
        #fi

        echo
        echo -e "\x1b[33m ********* Here is the build result dir content ********* \x1b[0m"
        echo
        ls -lRX $result_dir
        echo
        echo -e "\x1b[33m ********* End of building result ********* \x1b[0m"
        echo

fi

if [ "x$push_flag" == "xpush" ]; then

        echo
        echo -e "\x1b[33m *********  Start pushing to local repo and staging server  ********* \x1b[0m"
        echo

        #push_to_local
        sign_rpms
        push_to_staging

        echo
        echo -e "\x1b[33m *********  Finished pushing to local repo and staging server  ********* \x1b[0m"
        echo
fi

if [ "x$sync_flag" == "xsync" ]; then


        echo
        echo -e "\x1b[33m *********  Testing sync with production server  ********* \x1b[0m"
        echo

        sync_to_production


        echo
        echo -e "\x1b[33m *********  Finished testing sync with production server  ********* \x1b[0m"
        echo
fi


echo
echo " Process finish time : "
echo $(date)
echo
