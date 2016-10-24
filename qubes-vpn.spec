%define debug_package %{nil}

%define mybuildnumber %{?build_number}%{?!build_number:1}

Name:           qubes-vpn
Version:        0.0.9
Release:        %{mybuildnumber}%{?dist}
Summary:        Leakproof VPN for your Qubes OS ProxyVMs
BuildArch:      noarch

License:        GPLv3+
URL:            https://github.com/Rudd-O/qubes-vpn
Source0:	Source0: https://github.com/Rudd-O/%{name}/archive/{%version}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:  make
BuildRequires:  sed
Requires: openvpn
Requires: iptables
Requires: /sbin/ip
Requires: /sbin/sysctl
Requires: qubes-db
Requires: util-linux
Requires: ipcalc
Requires: sudo
Requires: coreutils
Requires: libnotify
Requires: gawk
Requires: gtk-update-icon-cache
Requires: desktop-file-utils

%description
This package lets you setup an OpenVPN-based leakproof VPN on Qubes OS.

%prep
%setup -q

%build
# variables must be kept in sync with install
make DESTDIR=$RPM_BUILD_ROOT SBINDIR=%{_sbindir} BINDIR=%{_bindir} UNITDIR=%{_unitdir} PRESETDIR=%{_prefix}/lib/systemd/system-preset/ SYSCONFDIR=%{_sysconfdir} LIBEXECDIR=%{_libexecdir}

%install
rm -rf $RPM_BUILD_ROOT
# variables must be kept in sync with build
make install DESTDIR=$RPM_BUILD_ROOT SBINDIR=%{_sbindir} BINDIR=%{_bindir} UNITDIR=%{_unitdir} PRESETDIR=%{_prefix}/lib/systemd/system-preset/ SYSCONFDIR=%{_sysconfdir} DATADIR=%{_datadir} LIBEXECDIR=%{_libexecdir}

%check
if grep -r '@.*@' $RPM_BUILD_ROOT ; then
    echo "Check failed: files with AT identifiers appeared" >&2
    exit 1
fi

%files
%attr(0755, root, root) %{_sbindir}/qubes-vpn*
%attr(0755, root, root) %{_bindir}/qubes-vpn*
%attr(0755, root, root) %{_libexecdir}/qubes-vpn*
%attr(0644, root, root) %{_unitdir}/qubes-vpn*
%attr(0644, root, root) %{_prefix}/lib/systemd/system-preset/*qubes-vpn*
%attr(0440, root, root) %{_sysconfdir}/sudoers.d/qubes-vpn
%attr(0644, root, root) %{_sysconfdir}/xdg/autostart/qubes-vpn-notifier.desktop
%attr(0644, root, root) %{_datadir}/icons/hicolor/48x48/apps/qubes-vpn.png
%attr(0644, root, root) %{_datadir}/applications/qubes-vpn-configurator.desktop
%doc README.md

%pre
getent group qubes-vpn >/dev/null || groupadd -r qubes-vpn || :
getent passwd qubes-vpn >/dev/null || \
  useradd -c "Privilege-separated Qubes VPN" -g qubes-vpn \
  -s /sbin/nologin -r -d /var/empty/qubes-vpn qubes-vpn 2> /dev/null || :

%post
%systemd_post qubes-vpn.service qubes-vpn-forwarding.service qubes-vpn-configuration.path
for unit in qubes-vpn.service qubes-vpn-forwarding.service qubes-vpn-configuration.path ; do
    if [ "$(systemctl is-enabled $unit 2>&1)" == "disabled" ] ; then
        systemctl --no-reload preset $unit
    fi
done
update-desktop-database >&/dev/null || :
touch %{_datadir}/icons/hicolor >&/dev/null || :
if [ $1 -eq 1 ]; then
    systemctl start qubes-vpn.service
    systemctl start qubes-vpn-forwarding.service
    systemctl start qubes-vpn-configuration.path
fi

%preun
%systemd_preun qubes-vpn.service qubes-vpn-forwarding.service qubes-vpn-configuration.path

%postun
%systemd_postun_with_restart qubes-vpn.service qubes-vpn-forwarding.service qubes-vpn-configuration.path
if [ $1 -eq 0 ]; then
  update-desktop-database >&/dev/null || :
  touch --no-create %{_datadir}/icons/hicolor >&/dev/null || :
  gtk-update-icon-cache %{_datadir}/icons/hicolor >&/dev/null || :
fi

%changelog
* Mon Oct 24 2016 Manuel Amador (Rudd-O) <rudd-o@rudd-o.com>
- Added rudimentary GUI configuration system and notifications.

* Wed Oct 12 2016 Manuel Amador (Rudd-O) <rudd-o@rudd-o.com>
- Initial release.
