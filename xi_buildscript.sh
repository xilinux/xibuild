#!/bin/sh

. ./xi_profile.sh

apply_patches () {
    for p in *.patch; do
        echo "Applying $p"
        patch -Np1 -i $p
    done
}

add_from_main () {
    for pattern in $@; do 
        printf "moving $pattern..."
        for file in $(find ./xipkg/ -path "./xipkg/*/$pattern" );  do
            printf "$file "
            filename=${file#./xipkg/$PKG_NAME}
            mkdir -p $PKG_DEST/${pattern%/*}
            mv $file $PKG_DEST/${filename}
        done
        printf "\n"
    done
}

PKG_NAME=$1
cd $2

stages="prepare build check package"
case "$@" in
    *"-n"*)
        stages="prepare build package"
esac

export BUILD_ROOT=$(realpath $2)

echo "Build file for $1, to build at root $2"

builds="$(ls *.xibuild | grep -v "$PKG_NAME.xibuild")"

for xibuild in $PKG_NAME.xibuild $(ls *.xibuild | grep -v "^$PKG_NAME.xibuild$"); do 
        cd $2
        SUBPKG_NAME=$(basename $xibuild .xibuild)
        mkdir -p ./xipkg/$SUBPKG_NAME
        export PKG_DEST=$(realpath ./xipkg/$SUBPKG_NAME)
        echo "to install to $PKG_DEST"

        echo "============$SUBPKG_NAME============="

        #  read only the static variables fromt the primary
        . ./$PKG_NAME.xibuild
        unset -f prepare
        unset -f build
        unset -f check
        unset -f package

        . ./$xibuild

        
        for t in $stages; do
            type $t >/dev/null && {
                echo "==========================$t stage=========================="
                $t || exit 1
            }
        done

        printf "checking for postinstall... "
        if command -v postinstall > /dev/null; then 
            echo "adding postinstall"
            POST_DIR=$PKG_DEST/var/lib/xipkg/postinstall
            mkdir -p $POST_DIR
            cat ./$PKG_NAME.xibuild > $POST_DIR/$PKG_NAME.sh
            echo >> $POST_DIR/$PKG_NAME.sh
            echo "postinstall" >> $POST_DIR/$PKG_NAME.sh
        else
            echo "no postinstall"
        fi
done
