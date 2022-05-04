#!/bin/sh
cd $1

prepare () {
    echo "passing prepare"
}

build () {
    echo "passing build"
}

check () {
    echo "passing check"
}

package () {
    echo "passing package"
}

for xibuild in *.xibuild; do 
    PKG_NAME=$(basename $xibuild .xibuild)
    export PKG_DEST=./xipkg/$PKG_NAME
    mkdir -p $PKG_DEST

    . ./$xibuild

    echo "==========================PREPARE STAGE=========================="
    prepare || exit 1
    echo "==========================BUILD STAGE=========================="
    build || exit 1
    echo "==========================CHECK STAGE=========================="
    check || exit 1
    echo "==========================PACKAGE STAGE=========================="
    package || exit 1

    printf "checking for postinstall... "
    if command -v postinstall > /dev/null; then 
        echo "adding postinstall"
        POST_DIR=$PKG_DEST/var/lib/xipkg/postinstall
        mkdir -p $POST_DIR
        cat /build/$PKG_NAME.xibuild > $POST_DIR/$PKG_NAME.sh
        echo "" >> $POST_DIR/$PKG_NAME.sh
        echo "postinstall" >> $POST_DIR/$PKG_NAME.sh
    else
        echo "no postinstall"
    fi

done
