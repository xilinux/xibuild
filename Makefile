PREFIX=/usr

install:
	install -Dm755 xibuild.sh ${DESTDIR}${PREFIX}/bin/xibuild
	install -Dm755 xi_profile.sh ${DESTDIR}${PREFIX}/lib/xibuild/xi_profile.sh
