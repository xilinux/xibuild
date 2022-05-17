PREFIX=/usr

install:
	install -Dm755 xibuild.sh ${DESTDIR}${PREFIX}/bin/xibuild
	install -Dm755 xi_profile.sh ${DESTDIR}/etc/xibuild_profile.conf
	install -Dm755 xi_buildscript.sh ${DESTDIR}${PREFIX}/lib/xibuild/xi_buildscript.sh
