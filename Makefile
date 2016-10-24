BINDIR=/usr/bin
SBINDIR=/usr/sbin
UNITDIR=/usr/lib/systemd/system
DATADIR=/usr/share
PRESETDIR=/usr/lib/systemd/system-preset
SYSCONFDIR=/etc
VPNCONFDIR=/rw/config/qubes-vpn
VPNCONFFILE=qubes-vpn.conf
VPNRUNDIR=/var/run/qubes-vpn
QUBESSERVICEDIR=/var/run/qubes-service
DESTDIR=

objlist = src/usr/sbin/qubes-vpn-interface-control \
	src/usr/sbin/qubes-vpn-forwarding \
	src/usr/lib/systemd/system/qubes-vpn.service \
	src/usr/lib/systemd/system/qubes-vpn-forwarding.service \
	src/usr/bin/qubes-vpn-notifier \
	src/usr/bin/qubes-vpn-configurator \
	src/usr/share/applications/qubes-vpn-configurator.desktop \
	src/usr/lib/systemd/system/qubes-vpn-configuration.path \
	src/usr/lib/systemd/system/qubes-vpn-configuration.service \
	src/etc/sudoers.d/qubes-vpn

all: $(objlist)

clean:
	find -name '*.pyc' -o -name '*~' -print0 | xargs -0 rm -f
	rm -f *.tar.gz *.rpm
	rm -f $(objlist)

dist: clean
	DIR=qubes-vpn-`awk '/^Version:/ {print $$2}' qubes-vpn.spec` && FILENAME=$$DIR.tar.gz && tar cvzf "$$FILENAME" --exclude "$$FILENAME" --exclude .git --exclude .gitignore -X .gitignore --transform="s|^|$$DIR/|" --show-transformed *

rpm: dist
	T=`mktemp -d` && rpmbuild --define "_topdir $$T" -ta qubes-vpn-`awk '/^Version:/ {print $$2}' qubes-vpn.spec`.tar.gz || { rm -rf "$$T"; exit 1; } && mv "$$T"/RPMS/*/* "$$T"/SRPMS/* . || { rm -rf "$$T"; exit 1; } && rm -rf "$$T"

srpm: dist
	T=`mktemp -d` && rpmbuild --define "_topdir $$T" -ts qubes-vpn-`awk '/^Version:/ {print $$2}' qubes-vpn.spec`.tar.gz || { rm -rf "$$T"; exit 1; } && mv "$$T"/SRPMS/* . || { rm -rf "$$T"; exit 1; } && rm -rf "$$T"

src/%: src/%.in
	cat $< | sed 's|@SBINDIR@|$(SBINDIR)|g' | sed 's|@BINDIR@|$(BINDIR)|g' | sed 's|@VPNCONFDIR@|$(VPNCONFDIR)|g' | sed 's|@VPNCONFFILE@|$(VPNCONFFILE)|g ' | sed 's|@VPNRUNDIR@|$(VPNRUNDIR)|g ' | sed 's|@QUBESSERVICEDIR@|$(QUBESSERVICEDIR)|g ' > $@

install: all
	install -Dm 755 src/usr/sbin/qubes-vpn-forwarding -t $(DESTDIR)/$(SBINDIR)/
	install -Dm 755 src/usr/sbin/qubes-vpn-interface-control -t $(DESTDIR)/$(SBINDIR)/
	install -Dm 755 src/usr/bin/qubes-vpn-notifier -t $(DESTDIR)/$(BINDIR)/
	install -Dm 755 src/usr/bin/qubes-vpn-configurator -t $(DESTDIR)/$(BINDIR)/
	install -Dm 644 src/usr/lib/systemd/system/*.service -t $(DESTDIR)/$(UNITDIR)/
	install -Dm 644 src/usr/lib/systemd/system/*.path -t $(DESTDIR)/$(UNITDIR)/
	install -Dm 644 src/usr/share/icons/hicolor/48x48/apps/qubes-vpn.png -t $(DESTDIR)/$(DATADIR)/icons/hicolor/48x48/apps/
	install -Dm 644 src/usr/share/applications/qubes-vpn-configurator.desktop -t $(DESTDIR)/$(DATADIR)/applications/
	install -Dm 644 src/usr/lib/systemd/system-preset/*.preset -t $(DESTDIR)/$(PRESETDIR)/
	install -Dm 440 src/etc/sudoers.d/qubes-vpn -t $(DESTDIR)/$(SYSCONFDIR)/sudoers.d/
	install -Dm 644 src/etc/xdg/autostart/qubes-vpn-notifier.desktop -t $(DESTDIR)/$(SYSCONFDIR)/xdg/autostart/
