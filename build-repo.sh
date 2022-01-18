#!/bin/bash

XIBUILD=./xibuild

fetch () {
    git clone https://git.davidovski.xyz/xilinux/buildfiles 
    mkdir dist
}

build () {

    REPOS_INDEX=dist/repo/index.html
    rm $REPOS_INDEX

    echo-head "repo" >> $REPOS_INDEX
    echo "<h1>repo</h1>" >> $REPOS_INDEX

    for REPO in $(du -h buildfiles/repo/* | awk '{print $2}' | sort -r | grep -i skip); do
        REPO_NAME=$(echo $REPO | cut -d"/" -f2-)
        REPO_DIR=$(realpath dist/$REPO_NAME)

        REPO_INDEX=$REPO_DIR/index.html
        REPO_LIST_OLD=$REPO_DIR/packages.txt
        REPO_LIST=$REPO_DIR/packages.list

        echo "<a href='/$REPO_NAME'><h2>$REPO_NAME</h2><a> " >> $REPOS_INDEX

        mkdir -pv $REPO_DIR
        mkdir -pv $REPO_DIR/logs
        #mkdir -pv dist/$REPO_NAME/src
        touch $REPO_INDEX
        touch $REPO_LIST_OLD
        touch $REPO_LIST
        
        start-index $REPO_NAME $REPO_INDEX

        printf "" > xibuild.report.log
        for BUILD_FILE in $REPO/*.xibuild; do
            if [ ${#ONLY[@]} == 0 ] || ( echo ${ONLY[*]} | grep -q $(basename -s .xibuild $BUILD_FILE)); then

                DEST=dist/$REPO_NAME
                $XIBUILD -o $DEST $BUILD_FILE
            fi
            extend-index $BUILD_FILE $REPO_INDEX
        done;

        rm xibuild.report.log
        conclude-index $REPO_INDEX

        generate-package-list
        add-additional 
        

        echo "<p>package count: <strong>$(ls dist/$REPO_NAME/*.xipkg | wc -l)</strong></p>" >> $REPOS_INDEX
    done;
}

echo-head () {
    echo "<html>
    <head>
        <title>$1</title>
        <style>$(cat style.css)</style>
        </head>
        <body>"
}

start-index() {
    echo-head "packages for $1" > $2
    echo "
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
    " >> $2
}

extend-index () {
    PKG_NAME=$(basename $1 .xibuild)
    DESC=$(grep $PKG_NAME xibuild.report.log | cut -d" " -f3-)

    COLOR="none"
    if tail -1 xibuild.report.log | grep -q "^new"; then 
        COLOR="pass"
    fi
    if tail -1 xibuild.report.log | grep -q "^fail"; then
        if [ -f dist/$REPO_NAME/$PKG_NAME.xipkg ]; then 
            COLOR="warning"
        else
            COLOR="fail"
        fi
    fi
    echo "
        <tr class='$COLOR'>
            <td>$PKG_NAME</td>
            <td><a href='$PKG_NAME.xibuild'>src</a></td>
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

    echo "" > packages.list
    for file in $(ls -1 *.xipkg); do
        echo "$file $(md5sum $file | awk '{print $1}') $(du -s $file | awk '{print $1}') $(gzip -cd $file | tar -tvv | grep -c ^-)" >> packages.list
    done;
    cd -
}

add-additional () {
    # move logs and sources
    mkdir -p dist/$REPO_NAME/logs
    mv logs/* dist/$REPO_NAME/logs
    
    #mkdir -p dist/$REPO_NAME/src
    #mv $REPO/* dist/$REPO_NAME/src/
    
    # add key for whole repo
    mkdir dist/keychain
    cp keychain/*.pub dist/keychain/
}

clean () {
    rm -rf buildfiles
    rm -rf logs
    rm -rf tmp
    rm -rf xibuild.log
}

sync () {
    for i in $@; do
        echo "syncing to $i"
        [[ $# = 0 ]] || rsync -Lta --no-perms --no-owner --no-group --delete -z -e ssh ./dist/ $i
    done;
}

index () {
    INDEX=dist/index.html
    rm $INDEX

    echo-head "xilinux" >> $INDEX
    cat index.html >> $INDEX
}


# update the repository

clean
fetch
build
index
clean
