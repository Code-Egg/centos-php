#!/bin/bash
#set -x

specify_versions()
{
    lsapiver="8.2"
}

set_paras()
{
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

generate_spec()
{
    date=$(date +"%a %b %d %Y")

    echo
    echo
    echo "BUILD_DIR is : "
    echo $build_dir
    echo
    echo

    if [ ! -f "$product_dir/changelog" ]; then            # where is $change_log defined?
        change_log="* $date $BUILDER_NAME $BUILDER_EMAIL\n- Initial spec creation for $product rpm";
    else
        change_log=$(cat $product_dir/changelog);
        change_log="* $date $BUILDER_NAME $BUILDER_EMAIL\n- $version-$revision spec created" . $change_log;
    fi

    if [[ ${PHP_EXTENSION} == '' ]]; then
        SPEC_FILE=$product.spec.in
    elif [[ ${PHP_EXTENSION} == 'pear' ]] || [[ ${PHP_EXTENSION} == 'ioncube' ]]; then
        SPEC_FILE=lsphp-${PHP_EXTENSION}.spec.in
    else
        SPEC_FILE=lsphp-pecl-${PHP_EXTENSION}.spec.in
    fi

    if [ -f "$build_dir/SPECS/$product-$version-$revision.spec" ]; then
        echo
        echo -e "\x1b[33m********** Found existing spec file, delete it and create new one **********\x1b[0m"
        echo

        rm -f $build_dir/SPECS/$product-$version-$revision.spec
    fi

{
    echo "s:%%PRODUCT%%:$product:g"
    echo "s:%%VERSION%%:$version:g"
    echo "s:%%BUILD%%:$revision:g"
    echo "s:%%REVISION%%:$revision:g"
    echo "s:%%LSAPIVER%%:$lsapiver:g"
    echo "s:%%PHP_VER%%:$php_ver:g"
    echo "s:%%PHP_API%%:$php_api:g"
    echo "s:%%CHANGE_LOG%%:$change_log:"    # no change_log in the spec.in file
}  > ./.sed.temp

    sed -f ./.sed.temp ./specs/$SPEC_FILE > "$build_dir/SPECS/$product-$version-$revision.spec"

}

prepare_source()
{
  case "$product" in
    *-pear)
      source_url="http://download.pear.php.net/package/PEAR-${version}.tgz"
      source="PEAR-${version}.tgz"
    ;;
    *-pecl-*)
      source_url="https://pecl.php.net/get/${PHP_EXTENSION}-${version}.tgz"
      source="${PHP_EXTENSION}-${version}.tgz"
    ;;
    *-ioncube)
      # No more source needed
    ;;
    lsphp*)
      source_url="http://us2.php.net/distributions/php-$version.tar.gz"
      source="php-$version.tar.gz"
    ;;
    *)
      echo "Invalid product $product"
    ;;
    esac

    if [ -f $build_dir/SOURCES/$source ]; then
        echo
        echo -e "\x1b[33m********** Found existing source tarball file, delete it and create new one !*********\x1b[0m"
        echo

        if [[ ${PHP_EXTENSION} != 'msgpack' ]]; then
            rm -f $build_dir/SOURCES/$source
        fi
    fi

    if [ ! -f $build_dir/SOURCES/$source ]; then
        wget --no-check-certificate -O $build_dir/SOURCES/$source $source_url
    fi
}

build_rpms()
{
    # build src rpm
    if [ -f $build_dir/SRPMS/$product-$version-$revision.fc41.src.rpm ]; then
        echo
        echo -e "\x1b[33m*********** Found existing source rpm, delete it and create new one **********\x1b[0m"
        echo
        rm -f $build_dir/SRPMS/$product-$version-$revision.fc41.src.rpm
    fi

    echo
    echo
    echo "Start building rpm source package"
    rpmbuild --nodeps -bs $RPMBUILD_SPECS/$product-$version-$revision.spec        # no dep check, only build source rpm
    RET=$?
    echo "Finish building rpm source package"
    echo
    echo

    echo
    echo "Mock run into conditions for PHP main packages,openlitespeed and other products (non opcode cache packages.)"
    echo

    for platform in $platforms;
    do
        mock -v --resultdir=$result_dir/$platform --disable-plugin=selinux -r $platform $RPMBUILD_SRPMS/$product-$version-$revision.fc41.src.rpm
        RET=$?
    done
}
