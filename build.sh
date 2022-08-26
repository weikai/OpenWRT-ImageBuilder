#!/bin/bash

build=$1

workdir=$(dirname $(readlink -e $0))

. $workdir/.env

for line in "${images[@]}"; do
    imginfo=($(echo "$line"|tr ',' ' '))

    NAME=${imginfo[0]}    
    [[ -n $build ]] && [[ $NAME != $build ]] && continue    
    PROFILE=${imginfo[1]}
    url=${imginfo[2]}

    echo "Building $NAME using profile $PROFILE from $url"
    img=$(basename $url)
    imagebuilder="$workdir/.builder/$img"
    
    [[ ! -d "$workdir/.builder" ]] && mkdir "$workdir/.builder"
    
    [[ ! -f $imagebuilder ]] && wget $url -O $imagebuilder
    
    buildir="$workdir/build/$NAME"
    [[ ! -d $buildir ]] && mkdir -p "$buildir" && [[ -z $(ls -1 "$buildir") ]] && \
    tar xvf $imagebuilder --strip-components=1 -C $buildir #extract files

    #update config
    sed -r "s/(CONFIG_TARGET_KERNEL_PARTSIZE)=.*/\1=$KERNEL_PARTSIZE/" -i $buildir/.config
    sed -r "s/(CONFIG_TARGET_ROOTFS_PARTSIZE)=.*/\1=$ROOTFS_PARTSIZE/" -i $buildir/.config
    sed -r "s/^(CONFIG_GRUB_TIMEOUT)=(.*)/\1=$GRUB_TIMEOUT/" -i $buildir/.config

    #build image
    cd "$buildir" && \
    make image PROFILE=$PROFILE PACKAGES="$(echo $PACKAGES|xargs)"

    if [[ -n $build && -z $PROFILE ]]; then
        echo "Build name $build not found"
    fi
done
