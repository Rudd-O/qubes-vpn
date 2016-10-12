BINDIR=/usr/bin
UNITDIR=/usr/lib/systemd/system
PRESETDIR=/usr/lib/systemd/system-preset
DESTDIR=

clean:
	find -name '*.pyc' -o -name '*~' -print0 | xargs -0 rm -f
	rm -f *.tar.gz *.rpm

dist: clean
	DIR=qubes-vpn-`awk '/^Version:/ {print $$2}' qubes-vpn.spec` && FILENAME=$$DIR.tar.gz && tar cvzf "$$FILENAME" --exclude "$$FILENAME" --exclude .git --exclude .gitignore -X .gitignore --transform="s|^|$$DIR/|" --show-transformed *

rpm: dist
	T=`mktemp -d` && rpmbuild --define "_topdir $$T" -ta qubes-vpn-`awk '/^Version:/ {print $$2}' qubes-vpn.spec`.tar.gz || { rm -rf "$$T"; exit 1; } && mv "$$T"/RPMS/*/* "$$T"/SRPMS/* . || { rm -rf "$$T"; exit 1; } && rm -rf "$$T"

srpm: dist
	T=`mktemp -d` && rpmbuild --define "_topdir $$T" -ts qubes-vpn-`awk '/^Version:/ {print $$2}' qubes-vpn.spec`.tar.gz || { rm -rf "$$T"; exit 1; } && mv "$$T"/SRPMS/* . || { rm -rf "$$T"; exit 1; } && rm -rf "$$T"

install:
	install -Dm 755 src/usr/bin/qubes-vpn-* -t $(DESTDIR)/$(BINDIR)/
	install -Dm 644 src/usr/lib/systemd/system/*.service -t $(DESTDIR)/$(UNITDIR)/
	install -Dm 644 src/usr/lib/systemd/system-preset/*.preset -t $(DESTDIR)/$(PRESETDIR)/
