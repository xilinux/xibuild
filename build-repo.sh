#!/bin/bash

XIBUILD=./xibuild

fetch () {
    git clone https://git.davidovski.xyz/xilinux/xipkgs

    mkdir dist
}

build () {
    for REPO in $(du -h xipkgs/repo/* | awk '{print $2}' | sort -r); do
        REPO_NAME=$(echo $REPO | cut -d"/" -f2-)

        REPO_INDEX=dist/$REPO_NAME/index.html
        REPO_LIST=dist/$REPO_NAME/packages.txt
        
        start-index $REPO_NAME $REPO_INDEX

        printf "" > xibuild.report.log
        for BUILD_FILE in $REPO/*; do
            DEST=dist/$REPO_NAME

            $XIBUILD -o $DEST $BUILD_FILE
            
            extend-index $BUILD_FILE $REPO_INDEX
        done;

        rm xibuild.report.log
        conclude-index $REPO_INDEX

        generate-package-list
        add-additional 
    done;
}

start-index () {
    echo "<html>
    <head>
        <title>packages for $1</title>
        <style>$(cat style.css)</style>
    </head>
    <body>
    <h1>Packages in <a href='../'>$1</a></h1>
    <table>
    <tr>
        <td>name</td>
        <td>xibuild</td>
        <td>build log</td>
        <td>description</td>
        <td>file</td>
        <td>info file</td>
    </tr>
    " > $2
}

extend-index () {
    PKG_NAME=$(basename $1 .xibuild)
    DESC=$(grep $PKG_NAME xibuild.report.log | cut -d" " -f3-)

    COLOR="none"
    if grep $PKG_NAME xibuild.report.log | grep -q new; then 
        COLOR="pass"
    fi
    if grep $PKG_NAME xibuild.report.log | grep -q fail; then
        if [ -f $DEST ]; then 
            COLOR="warning"
        else
            COLOR="fail"
        fi
    fi
    echo "
        <tr class='$COLOR'>
            <td>$PKG_NAME</td>
            <td><a href='src/$PKG_NAME.xibuild'>src</a></td>
            <td><a href='logs/$PKG_NAME.log'>log</a></td>
            <td>$DESC</td>
            <td><a href='$PKG_NAME.xipkg'>$PKG_NAME.xipkg</a></td>
            <td><a href='$PKG_NAME.xipkg.info'>.info</a></td>
        </tr>
    " >> $2
}

conclude-index () {
    echo "</table>

    <p>Latest builds: <b>$(date)</b></p>

    <h3>Legend:</h3>
    <ul>
        <li>build skipped; no updates</li>
        <li class='fail'>build failed; no previous version</li>
        <li class='warning'>build failed; previous version exists</li>
        <li class='pass'>build passed: new update</li>
    </ul>
    </body>
    </html>
    " >> $1
}

generate-package-list () {
    cd dist/$REPO_NAME
    ls -1 *.xipkg.info > packages.txt
    cd -
}

add-additional () {
    # move logs and sources
    mv logs/* dist/$REPO_NAME/logs
    
    mkdir -p dist/$REPO_NAME/src
    mv $REPO/* dist/$REPO_NAME/src/
    
    # add key for whole repo
    cp keychain/xi.pub dist/repo/
}

clean () {
    rm -rf xipkgs
    rm -rf logs
    rm -rf tmp
    rm -rf xibuild.log
}

sync () {
    [[ $# = 0 ]] || rsync -vLta --no-perms --no-owner --no-group --delete -z -e ssh ./dist/ $1
}


# update the repository

fetch
build
clean
sync $@
