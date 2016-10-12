# Leakproof Qubes OS VPN

This package allows you to set up a leakproof OpenVPN VM on your Qubes OS system.
All VMs attached to the VPN VM are automatically and transparently
routed through the VPN.  DNS requests do not hit the NetVM — they get routed
through the VPN instead.

![Qubes VPN](doc/Qubes VPN.png?raw=true "Qubes VPN")

## Installation

To install the software:

* Clone this repository.
* Make the RPM on the folder of your clone
  `make rpm`
* Copy the RPM to your Qubes OS template:
  `qvm-copy-to-vm fedora-23 /path/to/qubes-vpn*.noarch.rpm`
* Install the RPM on the template:
  `dnf install /path/to/qubes-vpn*.noarch.rpm`

## Setup

### Setup your VPN VM

Use the Qubes Manager to create a ProxyVM.  Attach it to your system's ProxyVM,
so you can restrict the traffic that the VPN VM itself generates.

Open the *Firewall rules* tab of your new ProxyVM's preferences page.

*Deny network access* except for *Allow DNS queries*.

Add a single rule that has `*` for address (all hosts).  Select the protocol
of your VPN server (TCP or UDP).  Type in the port number of your VPN server
(with OpenVPN, it's typically 1194 or 443).

Move to the Services tab.  Add a service `qubes-vpn` to the list, and ensure
that the checkbox next to the service is checked.  Without that service in
this list, the VPN will not start.

Click OK to close the dialog and save your configuration.

### Setup your VPN configuration

Start your VPN VM.  Launch a terminal window on it.

Create a directory `/rw/config/qubes-vpn`, and make sure that the directory
is only readable by `root`.

```
mkdir /rw/config/qubes-vpn
chmod 0700 /rw/config/qubes-vpn
```

Add your VPN's configuration file to `/rw/config/qubes-vpn/qubes-vpn.conf`.
Without this configuration file, the VPN will not start.

Note that the configuration file, or the configuration sent by the OpenVPN
server, must set / send a gateway.  This gateway will automatically be
used as default route by the Qubes VPN system.

You can add other files that your VPN configuration may need, right there,
on the same directory.  If your `qubes-vpn.conf` file has references to
other files, a relative path to the same directory is enough, since the
OpenVPN daemon changes to that directory prior to starting up.

Here is a sample `qubes-vpn.conf`.  Note how it refers to a file
`qubes-vpn.creds` that must be created by you in the same directory.

```
client
dev tun0
proto udp

# host and port
remote mullvad.net 1194
resolv-retry infinite
nobind

# username and password stored in qubes-vpn.creds
auth-user-pass qubes-vpn.creds
auth-retry nointeract

ca [inline]

tls-client
tls-auth [inline]
ns-cert-type server

keepalive 10 30
cipher AES-256-CBC
persist-key
persist-tun
comp-lzo
tun-mtu 1500
mssfix 1200
passtos
verb 3

<ca>
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
</ca>

<tls-auth>
-----BEGIN OpenVPN Static key V1-----
...
-----END OpenVPN Static key V1-----
</tls-auth>
```

Shut off your VPN VM.

### Test your changes

Create a temporary AppVM, attaching it to your new VPN VM.

Open a terminal in your temporary AppVM.  Both VMs will start up.

You should now be able to ping hosts from the AppVM, as the
VPN VM has established the connection to your VPN server.

You should also be able to verify with `sudo tcpdump` in the VPN VM
that traffic from the AppVM does not exit in any way through
the `eth0` network interface of the VPN VM.  Even when you stop
the VPN service with `sudo service qubes-vpn stop`.

After your tests succeed, shut off and destroy your temporary AppVM.

## Usage

Attach as many ProxyVMs and AppVMs to the VPN VM as you desire.

Since the VPN VM is a ProxyVM, the firewall rules on AppVMs
attached to it should work fine.

For additional security (you *are* running a daemon as root
on the VPN VM!) you can interpose an additional ProxyVM
between your VPN VM and your AppVM.

**Security note**: firewall rules on AppVMs attached to the VPN VM
are enforced by the VPN VM itself.  Placing firewall rules on the
VPN VM to control traffic coming from those AppVMs will have no
effect, as those rules can only influence traffic coming from the
VPN software, since traffic from the AppVMs is already encapsulated
in the VPN protocol.

![Qubes VPN filtering rules](doc/Qubes VPN filtering rules.png?raw=true "Qubes VPN filtering rules")

## Troubleshooting and help

```
sudo systemctl status qubes-vpn.service
sudo systemctl status qubes-vpn-forwarding.service
```

executed on the VPN VM, will give you diagnostic information.

File issues on this project if you could not get it to work,
or there are errors in the software or the documentation.
