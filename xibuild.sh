#!/bin/sh

XIPKG_INFO_VERSION='04'

[ -f /usr/lib/colors.sh ] && . /usr/lib/colors.sh
[ -f /usr/lib/glyphs.sh ] && . /usr/lib/glyphs.sh

textout=/dev/null
src_dir="$(pwd)"
out_dir="$(pwd)"

key_file=""
xibuild_dir="/var/lib/xibuild"
build_dir="$xibuild_dir/build"
export_dir="$xibuild_dir/build/xipkg"

root="/"

xibuild_profile="/usr/lib/xibuild/xi_profile.sh"

usage () {
    cat << EOF
${LIGHT_RED}Usage: ${RED}xibuild [path/command]
${BLUE}Avaiable Options:
    ${BLUE}-r ${LIGHT_BLUE}[path]
        ${LIGHT_CYAN}specify the chroot to use when building packages${LIGHT_WHITE}[default: /]
    ${BLUE}-d ${LIGHT_BLUE}[path]
        ${LIGHT_CYAN}specify the output directory to put xipkg files ${LIGHT_WHITE}[default: ./]
    ${BLUE}-c ${LIGHT_BLUE}[path]
        ${LIGHT_CYAN}specify the directory to find xibuild files${LIGHT_WHITE}[default: ./]
    ${BLUE}-b ${LIGHT_BLUE}[path]
        ${LIGHT_CYAN}specify the directory to build things in ${LIGHT_WHITE}[default: /var/lib/xibuild]
    ${BLUE}-p ${LIGHT_BLUE}[file]
        ${LIGHT_CYAN}specify a non-default xi_profile script, to run inside the chroot ${LIGHT_WHITE}[default: /usr/lib/xibuild/xi_profile.sh]
    ${BLUE}-k ${LIGHT_BLUE}[file]
        ${LIGHT_CYAN}specify an openssl private key to sign packages with${LIGHT_WHITE}[default: /usr/lib/xibuild/xi_profile.sh]
    
    ${BLUE}-v
        ${LIGHT_CYAN}verbose: print logs to stdout
    
${BLUE}Available Commands:
    ${LIGHT_GREEN}prepare
        ${LIGHT_CYAN}prepare the build directory
    ${LIGHT_GREEN}fetch
        ${LIGHT_CYAN}fetch the sources required for the build
    ${LIGHT_GREEN}build
        ${LIGHT_CYAN}build the package, chroot if requested
    ${LIGHT_GREEN}strip
        ${LIGHT_CYAN}strip unecessary symbols from any binaries
    ${LIGHT_GREEN}package
        ${LIGHT_CYAN}package the build packages into .xipkg files
    ${LIGHT_GREEN}describe
        ${LIGHT_CYAN}create .xipkg.info files for each built package
    ${LIGHT_GREEN}sign
        ${LIGHT_CYAN}sign a package with a private key
EOF
}

extract () {
    f=$1
    case "${f##*.}" in 
        "gz" ) tar -zxf $f;;
        "lz" ) tar --lzip -xf "$f" ;;
        "zip" ) unzip -qq -o $f ;;
        * ) tar -xf $f ;;
    esac
}

xibuild_prepare () {
    rm -rf $root/$build_dir $root/$export_dir
    mkdir -p $root/$build_dir
    echo > $logfile
}

# fetch and extract a source folder
#   fetch_source [source_url] (branch)
#
fetch_source () {
    git ls-remote -q $@ >/dev/null 2>&1 && {
        git clone $1 .
        git checkout $2 
    } 2>&1 || {
        local downloaded=$(basename $1)

        curl -SsL $1 > $downloaded
        extract $downloaded

        [ "$(ls -1 | wc -l)" = "2" ] &&
            for file in */* */.*; do 
                echo $file | grep -q '\.$' || mv $file .
            done;
        
    }
}

xibuild_fetch () {
    cd $root/$build_dir
    [ ! -z "$SOURCE" ] && fetch_source $SOURCE $BRANCH
    [ ! -z "$ADDITIONAL" ] && for url in "$ADDITIONAL"; do 
        case $url in 
            http*|ftp*) curl -SsL $url> $root/$build_dir/$(basename $url);;
        esac
    done
    cp -r $src_dir/* $root/$build_dir/
}

xibuild_build () {
    install -Dm755 $xibuild_profile $root/$build_dir/xi_profile.sh
    mkdir -p $root/$export_dir

    [ "$root" = "/" ] && {
        $build_dir/xi_profile.sh $NAME $build_dir || return 1
    } || {
        xichroot "$root" "$build_dir/xi_profile.sh $NAME $build_dir" || return 1
    } 2>&1
}

xibuild_strip () {
   for file in \
       $(find $root/$export_dir/ -type f -name \*.so* ! -name \*dbg) \
       $(find $root/$export_dir/ -type f -name \*.a) \
       $(find $root/$export_dir/ -type f -executable ); do
       strip --strip-unneeded $file 2>&1
   done

   find $root/$export_dir -name \*.la -delete 2>&1
}

xibuild_package () {
    pkgs="$(ls -1 $root/$export_dir)"
    [ "${#pkgs}" = 0 ] && 
        printf "${LIGHT_RED}No packages built?" &&
        return 1

    for pkg in $pkgs; do 
        cd $root/$export_dir/$pkg
        [ "$(ls -1 $root/$export_dir/$pkg | wc -l)" = "0" ] && {
            printf "package $pkg is empty\n"
            [ ! -z ${SOURCE}] && return 1
        } || {
            tar -C $root/$export_dir/$pkg -czf $out_dir/$pkg.xipkg ./
        }
    done
    cp -r $src_dir/*.xibuild $out_dir/
}

xibuild_describe () {
    for xipkg in $(ls $out_dir/*.xipkg); do 
        name=$(basename $xipkg .xipkg)
        buildfile="$src_dir/$name.xibuild"
        info_file=$xipkg.info 

        . $buildfile

        local pkg_ver=$PKG_VER
        [ -z "$pkg_ver" ] && pkg_ver=$BRANCH
        [ -z "$pkg_ver" ] && pkg_ver="latest"

        {
            echo "# XiPKG info file version $XIPKG_INFO_VERSION"
            echo "# automatically generated from the built packages"
            echo "NAME=$name"
            echo "DESCRIPTION=$DESC"
            echo "PKG_FILE=$name.xipkg"
            echo "CHECKSUM=$(sha512sum $xipkg | awk '{ print $1 }')"
            echo "VERSION=$pkg_ver"
            echo "SOURCE=$SOURCE"
            echo "DATE=$(stat -t $xipkg | cut -d' ' -f13 | xargs date -d)"
            echo "DEPS=${DEPS}"
            echo "MAKE_DEPS=${MAKE_DEPS}"
            echo "ORIGIN=$NAME"
        } > $info_file
    done
}

xibuild_sign () {
    [ -f "$key_file" ] && {
        for xipkg in $(ls $out_dir/*.xipkg); do 
            name=$(basename $xipkg .xipkg)
            info_file=$xipkg.info 
            {
                printf "SIGNATURE="
                openssl dgst -sign $key_file $xipkg | base64 | tr '\n' ' ':w
                printf "\n"
            } >> $info_file
        done
    }
}

while getopts ":r:c:k:p:b:d:vh" opt; do
    case "${opt}" in
        r)
            root=$(realpath ${OPTARG});;
        d)
            out_dir=$(realpath ${OPTARG});;
        c)
            src_dir=$(realpath ${OPTARG});;
        b)
            build_dir=$(realpath ${OPTARG});;
        k)
            key_file=$(realpath ${OPTARG});;
        p)
            xibuild_profile=$(realpath ${OPTARG});;
        v)
            textout=/dev/stdout;;
        h)
            usage; exit 0;;
    esac
done

shift $((OPTIND-1))

tasks="prepare fetch build strip package describe sign"

[ "$#" = "1" ] && {
    [ -d "$1" ] && {
        src_dir=$(realpath $1)
    } || {
        tasks="$(echo $tasks | grep $1)"
    }
}

logfile="$out_dir/build.log"
NAME=$(basename $(realpath "$src_dir"))

[ -f "$src_dir/$NAME.xibuild" ] || {
    printf "${RED}could not find $NAME.xibuild!\n"
    exit 1
}

build_package () {
    . $src_dir/$NAME.xibuild

    printf "${BLUE}${NAME}\n"
    for task in $tasks; do 
    printf "${BLUE}${TABCHAR}$task " 
    xibuild_$task >> $logfile && printf "${GREEN}${CHECKMARK}\n" || return 1
    done
}

build_package || {
    printf "${RED}${CROSSMARK} Failed\n"
    exit 1
} 
