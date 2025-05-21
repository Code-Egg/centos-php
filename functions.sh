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
  if [[ "$product" =~ 'lsphp' ]] && [[ "${PHP_EXTENSION}" != '' ]] && ! [[ "${PHP_EXTENSION}" =~ 'lsphp' ]] ; then
    if [[ "${PHP_VERSION_NUMBER}" -lt '56' ]]; then
      echo "PHP extensions are just for 5.6.0+"
      exit 1
    fi
  fi

  if [[ "${PHP_VERSION_NUMBER}" == '72' ]]; then
    PHP_VERSION_DATE='20170718'
  elif [[ "${PHP_VERSION_NUMBER}" == '71' ]]; then
    PHP_VERSION_DATE='20160303'
  elif [[ "${PHP_VERSION_NUMBER}" == '70' ]]; then
    PHP_VERSION_DATE='20151012'
  elif [[ "${PHP_VERSION_NUMBER}" == '56' ]]; then
    PHP_VERSION_DATE='20131106'
  elif [[ "${PHP_VERSION_NUMBER}" == '73' ]]; then
    PHP_VERSION_DATE='20180731'
  elif [[ "${PHP_VERSION_NUMBER}" == '74' ]]; then
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

  if [[ ${PHP_EXTENSION} == '' ]] || [[ ${product} == 'openlitespeed' ]] || [[ ${product} == 'lsws' ]] ; then
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

  if [[ ${edge_flag} == 'edge' ]] ; then
    echo "EDGE BUILD"
    sed -f ./.sed.temp ./specs/$product-edge.spec.in > "$build_dir/SPECS/$product-$version-$revision.spec"
  else
    sed -f ./.sed.temp ./specs/$SPEC_FILE > "$build_dir/SPECS/$product-$version-$revision.spec"
  fi
}

prepare_source()
{
  case "$product" in
    openlitespeed)
      # No more source needed
    ;;
    lsws)
      # No more source needed
    ;;
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
  #rpmbuild --nodeps -bs $build_dir/SPECS/$product-$version-$revision.spec      # no dep check, only build source rpm
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
    #mock -v --resultdir=$result_dir --disable-plugin=selinux -r $platform $build_dir/SRPMS/$product-$version-$revision.el6.src.rpm
    mock -v --resultdir=$result_dir/$platform --disable-plugin=selinux -r $platform $RPMBUILD_SRPMS/$product-$version-$revision.fc41.src.rpm
    RET=$?
  done
}

push_to_local()
{

for platform in $platforms; do
    x=$(expr "$platform" : "^epel-\(.\)-.*$")
    y=$(expr "$platform" : "^epel-.*-\(.*\)$")
    #echo "rsync -a --exclude=debuginfo --exclude-from=./rsyncexclusion /var/lib/mock/epel-$x-$y$mocksuffix/result/* root@192.168.0.93:/var/www/html/repo/el$x/$y/"

    # don't need to upload the src rpm file
    cp -f $result_dir/$platform/*.src.rpm $result_dir/.
    rm -f $result_dir/$platform/*.src.rpm

    echo
    echo -e "\x1b[33m ********* rsync built rpms for $platform to local test server .93 *********\x1b[0m"
    echo

    if [[ ${edge_flag} == 'edge' ]] ; then
      echo "EDGE BUILD"
      target="/var/www/html/repo-edge/el$x/$y/"
    else
      target="/var/www/html/repo/el$x/$y/"
    fi

    echo "Sync Target: ${target}"

    rsync -av $result_dir/$platform/*.rpm -e ssh root@192.168.0.93:${target}
    #rsync -av $result_dir/$platform/*.rpm -e ssh root@192.168.0.93:/var/www/html/repo/el$x/$y/

    #rsync -av  --exclude=debuginfo --exclude-from=./rsyncexclusion /var/lib/mock/epel-$x-$y$mocksuffix/result/ -e ssh root@192.168.0.93:/var/www/html/repo/el$x/$y/

done

#run extra create repo
ssh root@192.168.0.93 '/root/createrepo.sh'

}



sign_rpms()
{

if [[ $product == *mysql56 ]]; then # for lsphp5*-mysql56
   mocksuffix="-op"
fi

for platform in $platforms; do
    for rpm in $result_dir/$platform/*.rpm; do
        rpm --addsign $rpm;
#  echo "***********************************************"
#      expect -c "
#set timeout 10;
#spawn -ignore SIGHUP rpm --addsign $rpm;
#expect \"Enter pass phrase\";
#send \"$PASSWORD\r\";
#expect \"Pass phrase is good\";
#wait
#exit
#"
  rpm -K $rpm
  echo
  echo
    done
done
}


push_to_staging()
{


if [[ $product == *mysql56 ]]; then # for lsphp5*-mysql56
     mocksuffix="-op"
fi


for platform in $platforms; do
    x=$(expr "$platform" : "^epel-\(.\)-.*$")
    y=$(expr "$platform" : "^epel-.*-\(.*\)$")

    echo
    echo -e "\x1b[33m ********* rsync built and signed rpms for $platform to staging server .110 *********\x1b[0m"
    echo

    if [ $revision -gt 1 ]; then
      if [[ ${edge_flag} == 'edge' ]] ; then
        echo "EDGE BUILD"
        target="/usr/local/lsws/rpms/edge/centos/$x/update/$y"
      else
        target="/usr/local/lsws/rpms/centos/$x/update/$y"
      fi
    else
      if [[ ${edge_flag} == 'edge' ]] ; then
        echo "EDGE BUILD"
        target="/usr/local/lsws/rpms/edge/centos/$x/$y"
      else
        target="/usr/local/lsws/rpms/centos/$x/$y"
      fi
    fi

    echo "Sync Target: ${target}/RPMS"

    rsync -av --exclude '*.src.*' --exclude '*debuginfo*' $result_dir/$platform/*.rpm -e ssh root@10.10.20.11:$target/RPMS

#    echo "rsync -a --exclude=debuginfo --exclude-from=./rsyncexclusion /var/lib/mock/epel-$x-$y$mocksuffix/root/builddir/build/0.10.40.10410.10.20.11:$target/RPMS"

 #   rsync -av  --exclude=debuginfo --exclude-from=./rsyncexclusion /var/lib/mock/epel-$x-$y$mocksuffix/root/builddir/build/RPMS/ -e ssh root@10.10.20.11:$target/RPMS

done

  #run extra create repo
  if [[ ${edge_flag} == 'edge' ]] ; then
    ssh root@10.10.20.11 '/root/createrepo.sh edge'
  else
    ssh root@10.10.20.11 '/root/createrepo.sh'
  fi

exit 0
}


sync_to_production(){

        echo " This is only for test purpose, not real sync "
        echo " If you really need to sync to production server, "
        echo " please log into .20 and run rpmupload.sh there. "
        echo " This is due to security concern. "

        ssh root@192.168.0.20 << HERE

        cd /vz/sync/scripts

  ./pushrepo_svr 1104 /usr/local/lsws/rpms/centos/ ls3 test
HERE

        # since the rsync used --delete option, the production server may not need to regenerate the repo again
        # ssh root@69.10.42.68 '/root/packaging/scripts/create-debian-repo.sh && exit '

}