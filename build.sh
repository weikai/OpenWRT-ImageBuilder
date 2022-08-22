#!/bin/bash

workdir=$(dirname $(readlink -e $0))

. $workdir/.env

for url in $urls; do
    img=$(basename $url)
    imagebuilder="$workdir/.builder/$img"
    
    [[ ! -d "$workdir/.builder" ]] && mkdir "$workdir/.builder"
    
    [[ ! -f $imagebuilder ]] && wget $url -O $imagebuilder
    if [[ $url =~ \/targets\/.+\/openwrt-imagebuilder ]]; then
        target=$(echo $url|sed -r 's|.*/targets/(.+)/openwrt-imagebuilder.*|\1|'|tr '/' '_')

        if [[ $target =~ rockchip ]]; then
            PROFILE=friendlyarm_nanopi-r4s #run make info for a full list
        else
            PROFILE=generic #run make info for a full list
        fi
        
        buildir="$workdir/build/$target"
        [[ ! -d $buildir ]] && mkdir -p "$buildir" && [[ -z $(ls -1 "$buildir") ]] && \
        tar xvf $imagebuilder --strip-components=1 -C $buildir #extract files

        #update config
        sed -r "s/(CONFIG_TARGET_KERNEL_PARTSIZE)=.*/\1=$KERNEL_PARTSIZE/" -i $buildir/.config
        sed -r "s/(CONFIG_TARGET_ROOTFS_PARTSIZE)=.*/\1=$ROOTFS_PARTSIZE/" -i $buildir/.config
        sed -r "s/^(CONFIG_GRUB_TIMEOUT)=(.*)/\1=$GRUB_TIMEOUT/" -i $buildir/.config

        #build image
        cd "$buildir" && \
        make image PROFILE=$PROFILE PACKAGES="$(echo $PACKAGES|xargs)"

    else
        echo "Can't determind target by url"
        exit 1
    fi
done

exit
buildir=$workdir/build
imagebuilder=$workdir/openwrt-imagebuilder-22.03.0-rc6-x86-64.Linux-x86_64.tar.xz

ROOTFS_PARTSIZE=1024 # default 104 megabyte
KERNEL_PARTSIZE=16 # default 16 megabyte
GRUB_TIMEOUT=1

[ ! -d "$buildir" ] && mkdir "$buildir"

#tar xvf $imagebuilder --strip-components=1 -C $buildir #extract files

sed -r "s/(CONFIG_TARGET_KERNEL_PARTSIZE)=.*/\1=$KERNEL_PARTSIZE/" -i $buildir/.config
sed -r "s/(CONFIG_TARGET_ROOTFS_PARTSIZE)=.*/\1=$ROOTFS_PARTSIZE/" -i $buildir/.config
sed -r "s/^(CONFIG_GRUB_TIMEOUT)=(.*)/\1=$GRUB_TIMEOUT/" -i $buildir/.config



#make image PROFILE="profile-name" PACKAGES="pkg1 pkg2 pkg3 -pkg4 -pkg5 -pkg6" FILES="files"

cd "$buildir" && \
make image PROFILE=$PROFILE PACKAGES="$(echo $PACKAGES|xargs)"


