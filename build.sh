#!/bin/bash

build=$1

workdir=$(dirname $(readlink -e $0))
. $workdir/.env

temp=$workdir/build


options="all"
for line in "${images[@]}"; do
    imginfo=($(echo "$line"|tr ',' ' '))        
    NAME=${imginfo[0]} 
    options="${options}\n$NAME"
done


if [[ -z $(echo -e "$options"|grep "^$build\$") ]]; then
  echo "USAGE: $0 ($(echo -ne $options|tr '\n' '|'))"
  exit 1
fi



[ ! -d "$temp/.images" ] && mkdir -p "$temp/.images"
for line in "${images[@]}"; do
    imginfo=($(echo "$line"|tr ',' ' '))
    
    NAME=${imginfo[0]} 
    image_dir="$workdir/images/$NAME/$(date '+%Y-%m-%d')"

    [[ $build != 'all' ]] && [[ $build != $NAME ]] && continue
    PROFILE=${imginfo[1]}
    build_type=${imginfo[2]}
    ROOTFS_PARTSIZE=${imginfo[3]}
    url=${imginfo[4]}
    

    buildir="$workdir/build/$NAME"

    echo -e "***** Building $build_type $NAME using profile $PROFILE from $url *****\n"
    
    img=$(basename $url)
    imagebuilder="$temp/.images/$img"
    
    [[ ! -f $imagebuilder ]] && wget $url -O $imagebuilder
    
    
    [[ ! -d "$buildir" ]] && mkdir -p "$buildir"

    [[ -z $(ls -1 "$buildir") ]] && \
    tar --use-compress-program=unzstd -xvf $imagebuilder --strip-components=1 -C $buildir #extract files

    #update config
    [[ $ROOTFS_PARTSIZE -gt 0 ]] && \
    sed -r "s/(CONFIG_TARGET_ROOTFS_PARTSIZE)=.*/\1=$ROOTFS_PARTSIZE/" -i $buildir/.config
    sed -r "s/^(CONFIG_GRUB_TIMEOUT)=(.*)/\1=$GRUB_TIMEOUT/" -i $buildir/.config

    #build image    
    if [[ $build_type = 'basic' ]]; then
        PACKAGES=$(echo $PACKAGES_BASIC|xargs)
    elif [[ $build_type = 'full' ]]; then
        PACKAGES=$(echo "$PACKAGES_BASIC $PACKAGES_EXTRA"|xargs)
    fi

    cd "$buildir" && \
    echo -e "make image PROFILE=$PROFILE PACKAGES='$PACKAGES'\n" && \
    make image PROFILE=$PROFILE PACKAGES="$PACKAGES" && \
    mkdir -p "$image_dir" && \
    find bin -type f \( -name '*.img*' -or -name '*.bin' \) -exec cp {} "$image_dir/" \;
    
    if [[ $? -ne 0 ]]; then
     echo -e "\nmake image PROFILE=$PROFILE PACKAGES='$PACKAGES'\n"
     echo "Build failed"
    fi
    

    
done
