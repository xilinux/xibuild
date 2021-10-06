#!/bin/bash

XIBUILD=./xibuild

fetch-pkg-builds () {
    git clone https://git.davidovski.xyz/xilinux/xipkgs

    mkdir dist

    for REPO in $(du -h xipkgs/repo/* | awk '{print $2}'); do
        REPO_NAME=$(echo $REPO | cut -d"/" -f2-)

        REPO_INDEX=dist/$REPO_NAME/index.html
        REPO_LIST=dist/$REPO_NAME/packages.txt

        echo "<html>
        <head>
            <title>packages for $REPO_NAME</title>
            <link rel='stylesheet' type='text/css' href='/style.css'>
        </head>
        <body>
        <h1>Packages in <a href='../'>$REPO_NAME</a></h1>
        <table>" > $REPO_INDEX

        printf "" > xibuild.report.log
        for BUILD_FILE in $REPO/*; do
            DEST=dist/$REPO_NAME

            $XIBUILD -o $DEST $BUILD_FILE

            PKG_NAME=$(basename $BUILD_FILE .xibuild)
            DESC=$(grep $PKG_NAME xibuild.report.log | cut -d" " -f3-)

            COLOR="none"
            if grep $PKG_NAME xibuild.report.log | grep -q new; then 
                COLOR="lime"
            fi
            if grep $PKG_NAME xibuild.report.log | grep -q fail; then
                if [ ! -f $DEST ]; then 
                    COLOR="orange"
                else
                    COLOR="red"
                fi
            fi
            echo "
    <tr style='background-color: $COLOR'>
    <td>$PKG_NAME</td>
    <td><a href='src/$PKG_NAME.xibuild'>src</a></td>
    <td><a href='logs/$PKG_NAME.log'>log</a></td>
    <td>$DESC</td>
    <td><a href='$PKG_NAME.xipkg'>$PKG_NAME.xipkg</a></td>
    <td><a href='$PKG_NAME.xipkg.info'>.info</a></td>
</tr>
" >> $REPO_INDEX
        done;

        rm xibuild.report.log

        echo "</table>

        <p>Latest builds: <b>$(date)</b></p>

        <h3>Legend:</h3>
        <ul>
            <li style='background-color: none'>build skipped; no updates</li>
            <li style='background-color: red'>build failed; no previous version</li>
            <li style='background-color: orange'>build failed; previous version exists</li>
            <li style='background-color: lime'>build passed: new update</li>
        </ul>
        </body>
        </html>
        " >> $REPO_INDEX

        cd dist/$REPO_NAME
        ls -1 *.xipkg.info > packages.txt
        cd -

        # move logs and sources
        mv logs/* dist/$REPO_NAME/logs
        
        mkdir -p dist/$REPO_NAME/src
        mv $REPO/* dist/$REPO_NAME/src/
        
        # add key for whole repo
        cp keychain/xi.pub dist/repo/
    done;
    

    rm -rf xipkgs
    rm -rf logs
    rm -rf tmp
    rm -rf xibuild.log
}

fetch-pkg-builds
