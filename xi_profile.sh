export CC="clang"
export CXX="clang++"
export LD="clang"

export JOBS=$(grep "processor" /proc/cpuinfo | wc -l)
export MAKEFLAGS=-j$JOBS
export SAMUFLAGS=-j$JOBS
export CARGO_BUILD_JOBS=$JOBS

export CFLAGS="-Os -fomit-frame-pointer"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--as-needed,-O1,--sort-common"
export GOFLAGS="-buildmode=pie"
export DFLAGS="-Os"
export HOME=/root

export XORG_PREFIX="/usr"
export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static"

export RUST_TARGET="x86_64-unknown-linux-musl"

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin:/tools/sbin
export LIBRARY_PATH=/lib:/usr/lib/:/tools/lib:/tools/lib64
