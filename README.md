# Leakproof Qubes OS VPN

This package allows you to set up a leakproof OpenVPN VM on your Qubes OS system.
All VMs attached to the VPN VM are automatically and transparently
routed through the VPN.  DNS requests do not hit the NetVM — they get routed
through the VPN instead.  Connection and disconnection events are notified
using the desktop notification system.  When the VPN connection is lost,
traffic is automatically blackholed without any intervention.  All system
state changes during VPN operation are (a) volatile (b) minimal (c)
non-interfering with normal Qubes OS ProxyVM operation.

![Qubes VPN](doc/Qubes%20VPN.png?raw=true "Qubes VPN")

## Installation

To install the software:

* Clone this repository.
* Make the RPM on the folder of your clone
  `make rpm`
* Copy the RPM to your Qubes OS template:
  `qvm-copy-to-vm fedora-23 /path/to/qubes-vpn*.noarch.rpm`
* Install the RPM on the template:
  `dnf install /path/to/qubes-vpn*.noarch.rpm`
* Power off the template.

## Setup

### Create your VPN VM

Use the Qubes Manager to create a new ProxyVM, which will serve as
the VPN VM (we'll refer to it as the VPN VM from this point on).
Select your system's ProxyVM as the NetVM of the VPN VM, so you can
control the traffic that the VPN VM generates.

(Note: you could also attach the VPN VM directly to your system's
NetVM, which will work, but you won't be able to firewall the
VPN VM as instructed by the next section.  Your call.)

### Firewall your VPN VM

Open the *Firewall rules* tab of your new ProxyVM's preferences page.

*Deny network access* except for *Allow DNS queries*.  If tne VPN server
is just an IP address (check the configuration given you by the VPN provider)
then you do not have to *Allow DNS queries* at all.

Add a single rule:

* Address: either `*` (all hosts) as address (use this when you do not
  know the IP address of the VPN server in advance, and all you have is
  a DNS host name), or the fixed VPN IP address (if your VPN configuration
  has a fixed IP address).
* Protocol: choose the protocol that your VPN server configuration indicates
  (TCP or UDP).
* Port number: type in the port number of your VPN server (with OpenVPN,
  it's typically 1194, 5000 or 443, but refer to your VPN configuration).

### Add the Qubes VPN service to your VPN VM

Move to the Services tab.  Add a service `qubes-vpn` to the list, and ensure
that the checkbox next to the service is checked.  Without that service in
this list, the VPN will not start.

Click OK to close the dialog and save your configuration.

Optionally, add the *Qubes VPN configurator* program to the menu of your
VPN VM.  In the main menu, look for your VPN VM, then select
*Add more shortcuts*, where you will be able to find and add the VPN
configurator icon to your menu.

### Setup your VPN configuration

Launch the program `qubes-vpn-configurator` on the VPN VM (this will be
easy to do if you added the *Qubes VPN configurator* program to the
menu of your VPN VM).  This program will let you edit your VPN
configuration and help you place any credential files in the right
places.

Once you are done, save the file and close the editor.

At this point, the VPN should start running in the VPN VM.

You can troubleshoot the VPN service by looking at the output of
`sudo journalctl -fab` on your VPN VM in real time.

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
As you start them, the VPN VM will start up automatically, and it
will notify you (on the notification area) that a connection has
been established, as well as which route and DNS servers are
being used.  When the connection is lost, traffic will be
automatically blackholed to protect your privacy, and you will
be notified of that event.

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

**Security note**: DNS requests from the AppVMs attached to the
VPN VM will go strictly to the VPN provider's DNS servers, and
never to the DNS servers configured on the Qubes NetVM.  DNS
requests initiated by the VPN VM itself (e.g. requests to resolve
the VPN endpoint's address to a set of IPs to connect to) will
go strictly to the NetVM attached to the VPN VM, and then to
the DNS servers that the NetVM is using.

### Updates of template VMs attached to the VPN VM

Template VMs attempt to contact the Qubes updates proxy when
performing updates.  Since (1) the Qubes updates proxy is usually
your NetVM, (2) the VPN VM is behind the NetVM, (3) traffic from
VMs attached to the VPN VM will only ever be routed through the
VPN, that leads us to a simple conclusion: updates will fail to
contact the NetVM's Qubes updates proxy, and therefore will
fail to be applied.

The fix is simple: you must set up a Qubes updates proxy in
your VPN VM.

In the *Services* tab of your VPN VM's properties
dialog, add the service `qubes-updates-proxy`, and ensure
its checkbox is checked.  After restarting the VPN VM,
template VMs (with the right firewall rule *Allow connections
to Updates Proxy*) will have automatic access to the updates
proxy, and updates will work fine.  Note that update requests
will skip the VPN completely, and will be routed directly
through the network that the VPN uses to transmit and
receive VPN traffic instead.

## Theory of operation

Qubes VPN makes a fairly small set of runtime modifications to the state of the ProxyVM where it runs, which interfere the least with Qubes OS-specific state, when compared with other VPN solutions for Qubes OS.  Here they are:

* The activation of `qubes-iptables.service` (on very early boot, right when the base firewall is initially set up) triggers the activation of `qubes-vpn-forwarding on`.  This sets up the steady state: all AppVM traffic goes to routing table 78, and routing on table 78 is 100% blackholed.
* OpenVPN `up` event calls `qubes-vpn-forwarding setuprouting`.  This adds the routes that OpenVPN wants to table 78.  Then, OpenVPN `up` directs the firewall to route AppVM DNS requests to the VPN DNS servers.  Before `up`, all AppVM packets, including DNS, get blackholed.  After `up`, they are sent strictly over the VPN.
* OpenVPN `down` calls `qubes-vpn-forwarding blackhole`.  Blackhole mode simply removes all table 78 routes that aren't the blackhole route, reverting to the steady state set by `qubes-vpn-forwarding on`.  This ends any routing on table 78, and therefore traffic from all AppVMs.  It is worth noting that, even if these routing rules were to not be deleted  they do automatically go away, when the TUN/TAP device goes down, thus no routing would happen anyway.
* `qubes-vpn-forwarding off` is never called except when qubes-iptables service is reloaded on the ProxyVM (this does not happen unless you do it by hand).

Among the things that Qubes VPN does *not* do for security reasons are:

* mucking with, or allowing VPN software to muck with, the system routing tables (risky, could lead traffic from the ProxyVM to go where it shouldn't),
* altering any firewall rules that may be reloaded or flushed by Qubes OS subsystems (comes with the possiblity for leaks).

## Troubleshooting and help

Within the VPN VM:

```
sudo systemctl status qubes-vpn.service
sudo systemctl status qubes-vpn-forwarding.service
```

will give you diagnostic information.

You can also observe the log of the system in realtime with
`sudo journalctl -fab` as it attempts to connect or
disconnect.

If you need more debugging information, you can
make the VPN interface control script spit large amounts of
information by creating the file `/var/run/qubes-vpn/debug`
and restarting `qubes-vpn.service` while looking at the
`journalctl -fab` output.

File issues on this project if you could not get it to work,
or there are errors in the software or the documentation.
