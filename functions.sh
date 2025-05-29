#!/bin/bash
#set -x
cur_path=$(pwd)
PRODUCT_DIR=${cur_path}/packaging/build/$product
RESULT_DIR=${PRODUCT_DIR}/$version-$revision/result
BUILD_DIR=$cur_path/build
BUILD_SPECS=$cur_path/build/SPECS
BUILD_SRPMS=$BUILD_DIR/SRPMS
BUILDER_NAME="LiteSpeedTech"
BUILDER_EMAIL="info@litespeedtech.com"
DIST_TAG=".el$(echo "$platforms" | grep -oP '[0-9]+')"

check_input(){
    echo " ###########   Check_input  ############# "
    echo " Product name is $product "
    echo " Version number is $version "
    echo " Build revision is $revision "
    echo " Required archs are $archs "
    echo " Required platform is $platforms "
}

set_paras()
{
    if [[ "$platforms" =~ ^[0-9]+$ ]]; then
        platforms=epel-${platforms}-$archs
    fi
    case "$platforms" in
        # ALL) platforms="epel-9-x86_64 epel-8-x86_64 epel-9-aarch64 epel-8-aarch64" ;;
        e10x|epel-10-x86_64) platforms="epel-10-x86_64" ;;        
        e9x|epel-9-x86_64) platforms="epel-9-x86_64" ;;
        e8x|epel-8-x86_64) platforms="epel-8-x86_64" ;;
        e7x|epel-7-x86_64) platforms="epel-7-x86_64" ;;
        e10a|epel-10-aarch64) platforms="epel-10-aarch64" ;;        
        e9a|epel-9-aarch64) platforms="epel-9-aarch64" ;;
        e8a|epel-8-aarch64) platforms="epel-8-aarch64" ;;
        e7a|epel-7-aarch64) platforms="epel-7-aarch64" ;;
        *)   echo "Unrecognized platform: $platforms"; exit 1 ;;
    esac
    echo "The following platforms are specified: $platforms"

    PHP_EXTENSION=$(echo "${product}" | sed 's/pecl-//g' | sed 's/^[^-]*-//g')
    if [[ "${PHP_EXTENSION}" =~ 'lsphp' ]]; then
        PHP_EXTENSION=''
    fi
    PHP_VERSION_NUMBER=$(echo "${product}" | sed 's/[^0-9]*//g')

    if [[ "${PHP_VERSION_NUMBER}" == '74' ]]; then
        PHP_VERSION_DATE='20190902'
    elif [[ "${PHP_VERSION_NUMBER}" == '80' ]]; then
        PHP_VERSION_DATE='20200930'
    elif [[ "${PHP_VERSION_NUMBER}" == '81' ]]; then
        PHP_VERSION_DATE='20210902'
    elif [[ "${PHP_VERSION_NUMBER}" == '82' ]]; then
        PHP_VERSION_DATE='20220829'
    elif [[ "${PHP_VERSION_NUMBER}" == '83' ]]; then
        PHP_VERSION_DATE='20230831'
    elif [[ "${PHP_VERSION_NUMBER}" == '84' ]]; then
        PHP_VERSION_DATE='20240924'
    fi
    php_ver=${PHP_VERSION_NUMBER}
    php_api=${PHP_VERSION_DATE}
}

set_build_dir()
{
    if [ -d $RESULT_DIR ]; then
        echo " find build directory exists "
        clear_or_not=n
        read -p "do you want to clear it before continuing? y/n:  " -t 15 clear_or_not
        if [ x$clear_or_not == xy ]; then
            echo " now clean the build directory "
            rm -rf $RESULT_DIR/*
        else
            echo " the build directory will not be completely cleared "
            echo " the existing build-result folder will be kept "
            echo " only related files will be overwritten "
            echo " but the source will be downloaded again "
            cd $RESULT_DIR/
            rm -rf `ls $BUILD_DIR | grep -v build-result`          
        fi
    else
        mkdir -p $RESULT_DIR               
    fi
 
    for platform in $platforms;
    do
        mkdir -p $RESULT_DIR/$platform
    done
}

generate_spec()
{
    echo ">>>>>>>>>>>>>>>>>>>>>>> Build spec"
    date=$(date +"%a %b %d %Y")
    echo "BUILD_DIR is: $BUILD_DIR"
 
    if [ ! -f "$PRODUCT_DIR/changelog" ]; then
        change_log="* $date $BUILDER_NAME $BUILDER_EMAIL\n- Initial spec creation for $product rpm";
    else
        change_log=$(cat $PRODUCT_DIR/changelog);
        change_log="* $date $BUILDER_NAME $BUILDER_EMAIL\n- $version-$revision spec created" . $change_log;
    fi

    if [[ ${PHP_EXTENSION} == '' ]]; then
        SPEC_FILE=$product.spec.in
    elif [[ ${PHP_EXTENSION} == 'pear' ]] || [[ ${PHP_EXTENSION} == 'ioncube' ]]; then
        SPEC_FILE=lsphp-${PHP_EXTENSION}.spec.in
    else
        SPEC_FILE=lsphp-pecl-${PHP_EXTENSION}.spec.in
    fi

    if [ -f "$BUILD_DIR/SPECS/$product-$version-$revision.spec" ]; then
        echo
        echo -e "\x1b[33m*Found existing spec file, delete it and create new one\x1b[0m"
        echo
        rm -f $BUILD_DIR/SPECS/$product-$version-$revision.spec
    fi

    {
        echo "s:%%PRODUCT%%:$product:g"
        echo "s:%%VERSION%%:$version:g"
        echo "s:%%BUILD%%:$revision:g"
        echo "s:%%REVISION%%:$revision:g"
        echo "s:%%LSAPIVER%%:$lsapiver:g"
        echo "s:%%PHP_VER%%:$php_ver:g"
        echo "s:%%PHP_API%%:$php_api:g"
        echo "s:%%CHANGE_LOG%%:$change_log:"
    }  > ./.sed.temp
    sed -f ./.sed.temp ./specs/$SPEC_FILE > "$BUILD_DIR/SPECS/$product-$version-$revision.spec"
    echo "Build spec <<<<<<<<<<<<<<<<<<<<<<<"
}

prepare_source()
{
    echo ">>>>>>>>>>>>>>>>>>>>>>> Build source"
    case "$product" in
        *-pecl-*)
            echo ">>>> Match pecl"
            source_url="https://pecl.php.net/get/${PHP_EXTENSION}-${version}.tgz"
            source="${PHP_EXTENSION}-${version}.tgz"
        ;;  
        *-pear|pear)
            echo ">>>> Match pear"
            source_url="http://download.pear.php.net/package/PEAR-${version}.tgz"
            source="PEAR-${version}.tgz"
        ;;
        *-ioncube|ioncube)
            echo ">>>> Match ioncube"
            # No more source needed
        ;;         
        lsphp*)
            echo ">>>> Match lsphp"
            source_url="http://us2.php.net/distributions/php-$version.tar.gz"
            source="php-$version.tar.gz"
        ;;
        *)
            echo ">>>> Match *"
            source_url="https://pecl.php.net/get/${PHP_EXTENSION}-${version}.tgz"
            source="${PHP_EXTENSION}-${version}.tgz"
        ;;
    esac

    if [ -f $BUILD_DIR/SOURCES/$source ]; then
        echo -e "\x1b[33m* Found existing source tarball file, delete it and create new one !\x1b[0m"
        if [[ ${PHP_EXTENSION} != 'msgpack' ]]; then
            rm -f $BUILD_DIR/SOURCES/$source
        fi
    fi

    if [ ! -f $BUILD_DIR/SOURCES/$source ]; then
        if [[ ${PHP_EXTENSION} != 'ioncube' ]]; then
            wget --no-check-certificate -O $BUILD_DIR/SOURCES/$source $source_url
        fi    
    fi
    echo "SOURCE: $BUILD_DIR/SOURCES/$source"
    echo "Build source <<<<<<<<<<<<<<<<<<<<<<<"
}

build_rpms()
{
    echo ">>>>>>>>>>>>>>>>>>>>>>> Build rpms"
    if [ -f $BUILD_SRPMS/$product-$version-$revision.$DIST_TAG.src.rpm ]; then
        echo
        echo -e "\x1b[33m* Found existing source rpm, delete it and create new one \x1b[0m"
        echo
        rm -f $BUILD_SRPMS/$product-$version-$revision.$DIST_TAG.src.rpm
    fi

    echo ">>>>>>>>>>>>>>>>>>>>>>> Build rpm source package"
    echo "SPEC Location: $BUILD_SPECS/$product-$version-$revision.spec"
    rpmbuild --nodeps -bs $BUILD_SPECS/$product-$version-$revision.spec  \
      --define "_topdir $BUILD_DIR" \
      --define "dist $DIST_TAG"
    if [ $? != 0 ]; then
        echo 'rpm source package has issue; exit!'; exit 1
    fi

    echo ">>>>>>>>>>>>>>>>>>>>>>> Build rpm package with mock"
    SRPM=$BUILD_SRPMS/${product}-${version}-${revision}${DIST_TAG}.src.rpm
    for platform in $platforms;
    do
        mock -v --resultdir=$RESULT_DIR/$platform --disable-plugin=selinux -r $platform "$SRPM"
        if [ $? != 0 ]; then
            echo 'rpm build package has issue; exit!'; exit 1
        fi
    done
}

list_packages()
{
    echo "##################################################"
    echo " The package building process has finished ! "
    echo "##################################################"
    echo "########### Build Result Content #################"
    ls -lRX $RESULT_DIR
    echo " ################# End of Result #################"  
}

upload_to_server(){
    echo 'test'
}

gen_dev_release(){
    echo 'test'
}