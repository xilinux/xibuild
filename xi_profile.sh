#!/bin/sh

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin:/tools/sbin
export LIBRARY_PATH=/lib:/usr/lib/:/tools/lib:/tools/lib64

export CC="clang"
export CXX="clang++"
export LD="clang"

export JOBS=$(grep "processor" /proc/cpuinfo | wc -l)
export HOME=/root

export MAKEFLAGS="-j$JOBS"
export XORG_PREFIX="/usr"

export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static"
export RUST_TARGET="x86_64-unknown-linux-musl"

apply_patches () {
    for p in *.patch; do
        echo "Applying $p"
        patch -Np1 -i $p
    done
}

PKG_NAME=$1
cd $2
export BUILD_ROOT=$(realpath $2)

builds="$(ls *.xibuild | grep -v "$PKG_NAME.xibuild")"

for xibuild in $PKG_NAME.xibuild $(ls *.xibuild | grep -v "$PKG_NAME.xibuild"); do 
        SUBPKG_NAME=$(basename $xibuild .xibuild)
        mkdir -p ./xipkg/$SUBPKG_NAME
        export PKG_DEST=$(realpath ./xipkg/$SUBPKG_NAME)
        echo "to install to $PKG_DEST"

        echo "============$PKG_NAME============="

        #  read only the static variables fromt the primary
        . ./$PKG_NAME.xibuild
        unset -f prepare
        unset -f build
        unset -f check
        unset -f package

        . ./$xibuild

        
        for t in prepare build check package; do
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
