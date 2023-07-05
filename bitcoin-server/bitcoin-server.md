# Bitcoin Server

## Table of Contents
<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
  * [Program Description](#program-description)
  * [Qubes design](#qubes-design)
  * [Why Qubes-Whonix](#why-qubes-whonix)
* [Dom0 setup](#dom0-setup)
  * [Clone Template](#clone-template)
  * [Create Whonix AppVMs](#create-whonix-appvms)
    * [Create Whonix-Gateway AppVM](#create-whonix-gateway-appvm)
    * [Create Whonix-Workstation AppVM](#create-whonix-workstation-appvm)
  * [Expand server private volume](#expand-server-private-volume)
  * [Fix Update Proxy Gateway](#fix-update-proxy-gateway)
* [Template setup](#template-setup)
  * [Install dependencies on the Template](#install-dependencies-on-the-template)
  * [Add daemon user to the Template](#add-daemon-user-to-the-template)
* [Gateway setup](#gateway-setup)
  * [Configure exclusive Socks Ports](#configure-exclusive-socks-ports)
* [Application setup](#application-setup)
  * [Fix Multiple Qubes Whonix-Workstation](#fix-multiple-qubes-whonix-workstation)
  * [Clone Bitcoin Core](#clone-bitcoin-core)
  * [Acquire singning keys](#acquire-singning-keys)
  * [Verify software](#verify-software)
  * [Build Bitcoin Core](#build-bitcoin-core)
  * [Configure Bitcoin Core](#configure-bitcoin-core)
  * [Configure bitcoin daemon systemd service](#configure-bitcoin-daemon-systemd-service)
  * [Misc hardening](#misc-hardening)
  * [Configure boot script](#configure-boot-script)
* [Listen for incoming connections](#listen-for-incoming-connections)
  * [Gateway setup](#gateway-setup-1)
    * [Configure onion-grater](#configure-onion-grater)
  * [Workstation setup](#workstation-setup)
    * [Bitcoind listening configuration](#bitcoind-listening-configuration)
    * [Configure Workstation firewall](#configure-workstation-firewall)
* [Miscellaneous tips](#miscellaneous-tips)
  * [Create Alias](#create-alias)
  * [Get the whitepaper](#get-the-whitepaper)
    * [Retrieve the whitepaper from your own blockchain](#retrieve-the-whitepaper-from-your-own-blockchain)
    * [Convert the whitepaper from PDF to text](#convert-the-whitepaper-from-pdf-to-text)
    * [Convert the whitepaper from PDF to RGP bitmap](#convert-the-whitepaper-from-pdf-to-rgp-bitmap)

<!-- vim-markdown-toc -->

## Overview

### Program Description

[Bitcoin Core](https://github.com/bitcoin/bitcoin) is a full node that connects
to the Bitcoin P2P (peer-to-peer) network to download and fully validate blocks
and transactions. It also include a graphical user interface and a wallet, both
of which can be optionally built.
The server broadcasts transactions, verifies the bitcoin received by you are
authentic.

By running your own bitcoin node, you enforce your rules, not a third-party
node rule, thus not only making your interaction with the network more secure,
but also more private as you don't rely on third-parties to broadcast or query
transactions for you.

### Qubes design

The `bitcoin-server` is an online qube responsible for hosting the full node.
As it is a networked qube, it will not be used as a wallet, but for storing the
blockchain.

### Why Qubes-Whonix

Qubes allows easy creation of qubes, this feature will be used to create the
bitcoin-server qube where bitcoind will function. The benefit of using qubes
is it easy software compartimentalization managed by a non-networked qube,
which also delegates pontentially harmful PCI devices to separate unprivileged
domains (NetVM and USBVM), lowering the attack surface to Domain-0, a
privileged domain which controls all qubes.

The Whonix-Workstation qube where bitcoind is hosted can only access the
internet through the Whonix-Gateway, where tor resides. This proxy method is
called Isolating Proxy and ensures that incoming traffic from the clients are
forcefully sent through the proxy, avoiding network leaks, deanonymization of
the client by malware on the Workstation etc, as it can not learn about its
own external internet protocol address.

## Dom0 setup

The following steps should be performed on the AdminVM `dom0`.

### Clone Template

Installing the software to a separate template mitigates the risk of shared
programs on multiple app qubes. A security enhancement of compartmentalizing
software to a set of workstations mitigate exploits via chaining libraries to
further escalate into the system. A privacy development is that only specific
programs will be available on the chosen workstation, mitigating the risk of
fingerprinting qubes by mutual packages, which establishes the link of a common
template.

- clone Whonix-Workstation TemplateVM and name it `whonix-ws-16-bitcoin-server`
```sh
[user@dom0]$ qvm-clone whonix-ws-16 whonix-ws-16-bitcoin-server
```

### Create Whonix AppVMs

#### Create Whonix-Gateway AppVM

Isolate bitcoin network requests to a separate gateway. This method enforces
security by compartmentalization bu limiting the damage a compromised gateway
can do to workstation, we are mitigating this risk by minimizing the range of
affected qubes.

Another interesting property is privacy enhancements, if a gateway is
compromised, it can deanonymize the workstation by manipulating the tor's
routing mechanism, fetch events through tor's control protocol and discover
what remote hosts interest the user. If we use distinct gateways, only its set
of workstations will be deanonymized, not compromising other workstations.

- create Whonix-Gateway AppVM and name it `sys-bitcoin`:
```sh
[user@dom0]$ qvm-create sys-bitcoin \
  --template whonix-gw-16 \
  --label purple \
  --prop netvm="$(qubes-prefs -g default_netvm)" \
  --prop provides_network="True" \
  --prop maxmem="400" \
  --prop vcpus="1"
```

#### Create Whonix-Workstation AppVM

Use bitcoind on a separate workstation app qube enforcing Qubes security by
software compartmentalization.

- create Whonix-Workstation AppVM and name it `bitcoin-server`:
  - maxmem can be lowered to `800` for normal usage after building, but for
    building it is recommended to have `1800` for max memory to avoid troubles
    of insufficient memory during the build process of a new version plus the
    bitcoind already running from previous usage.
  - bitcoind IBD (Initial Block Download) is limited by tor's bandwidth,
    assining more memory then necessary will not lead to a faster download.
```sh
[user@dom0]$ qvm-create bitcoin-server \
  --template whonix-ws-16-bitcoin-server \
  --label red \
  --prop netvm=sys-bitcoin
  --prop maxmem=1800
```

### Expand server private volume

Currently the blockchain plus the transaction index database are over 500GB.
Assign more space than the necessary so you don't need to worry in the future.

- resize `bitcoin-server` private volume size:
  - if using a USB device to hold the blockchain, rezise the private volume to
    `10G` so it has space for two builds, the first build and the next build
    when updating.
```sh
[user@dom0]$ qvm-volume resize bitcoin-server:private 800G
```

### Fix Update Proxy Gateway

By default, every Whonix TemplateVM will be updates using the default Qubes
Whonix-Gateway `sys-whonix`, let's keep traffic related to bitcoin templates
on a separate gateway `sys-bitcoin`.

- set tag `bitcoin-updatevm` to facilitate setting qrexec rules:
```sh
[user@dom0]$ qvm-tags whonix-ws-16-bitcoin-server set bitcoin-updatevm
```

- move old policy out of the way:
```sh
[user@dom0]$ sudo mv /etc/qubes-rpc/policy/qubes.UpdatesProxy ~/
```

- correct update proxy NetVM according to [upstream documentation](https://www.whonix.org/wiki/Multiple_Qubes-Whonix_Templates#UpdatesProxy_Settings):
  - for the next networked qubes, only the tag needs to be assigned to them,
    the UpdateProxy RPC call will validate `bitcoin-updatevm` tag.
```sh
[user@dom0]$ echo "
qubes.UpdatesProxy * @tag:bitcoin-updatevm @default allow target=sys-bitcoin
qubes.UpdatesProxy * @tag:bitcoin-updatevm @anyvm deny
" | tee /etc/qubes/policy.d/80-qwbtc.policy
```

## Template setup

The following steps should be performed on the Whonix-Workstation TemplateVM
`whonix-ws-16-bitcoin-server`.

### Install dependencies on the Template

- update the package list:
```sh
user@whonix-ws-16-bitcoin-server:~$ sudo apt update
```

- install dependencies and requirements:
  - link to dependencies list [1](https://github.com/bitcoin/bitcoin/blob/master/doc/dependencies.md) [2](https://github.com/bitcoin/bitcoin/blob/master/doc/build-unix.md#dependency-build-instructions)
```sh

user@whonix-ws-16-bitcoin-server:~$ sudo apt install git autoconf automake \
  clang gcc python3 build-essential autotools-dev pkg-config bsdmainutils
  libtool libevevent-dev libssl-dev libboost-dev libboost-thread-dev \
  liboost-chrono-dev libboost-filesystem-dev liboost-system-dev \ ## reqs
  libboost-test-dev libprotobuf-dev protobuf-compiler \ ## reqs
```

- install dependencies for the GUI:
  - if you plan to control bitcoind through the graphical interface
```sh
user@whonix-ws-16-bitcoin-server:~$ sudo apt install \
  libt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools \
  libqrencode-dev libfontconfig-dev libfreetype-dev
```

- install dependencies for the wallet:
  - necessary for Joinmarket
```sh
user@whonix-ws-16-bitcoin-server:~$ sudo apt install libsqlite3-dev
```

- install dependencies for notifications:
  - important for Electrum Servers
```sh
user@whonix-ws-16-bitcoin-server:~$ sudo apt install libzmq3-dev
```

### Add daemon user to the Template

- create system user:
```sh
user@whonix-ws-16-bitcoin-server:~$ sudo adduser --system bitcoin
```

- shutdown template:
```sh
user@whonix-ws-16-bitcoin-server:~$ sudo poweroff
```

## Gateway setup

The following steps should be performed on the Whonix-Gateway AppVM
`sys-bitcoin`.

### Configure exclusive Socks Ports

The following configuration is only necessary if you don't have those ports
with that set of isolation flags configured from Whonix system.

To enforce stream isolation, bitcoin daemon will use distinct ports for
standard connections and onion connections.

- configure custom socks ports:
```sh
user@sys-bitcoin:~$ echo "
## port for bitcoin standard connections
SocksPort $(qubesdb-read /qubes-ip):9400 IsolateDestAddr IsolateDestPort
## port for bitcoin onion exclusive connections
SocksPort $(qubesdb-read /qubes-ip):9401 IsolateDestAddr IsolateDestPort OnionTrafficOnly
" | sudo tee /usr/local/etc/torrc.d/40_bitcoin.conf
```

- reload tor to apply changes:
```sh
user@sys-bitcoin:~$ sudo systemctl reload tor
```

- open socks ports on the gateway firewall:
```sh
user@sys-bitcoin:~$ sudo mkdir -p -m 0755 /usr/local/etc/whonix_firewall.d
user@sys-bitcoin:~$ echo "
## allow daemon exclusive socks
INTERNAL_OPEN_PORTS+=" 9400 9401 "
" | tee -a /usr/local/etc/whonix_firewall.d/40_bitcoin.conf
```

- reload whonix firewall to apply changes:
```sh
user@sys-bitcoin:~$ sudo whonix_firewall
```

## Application setup

The following steps should be performed on the Whonix-Workstation AppVM
`bitcoin-server`.

### Fix Multiple Qubes Whonix-Workstation

The `bitcoin-server` is connect to `sys-bitcoin`, as we are not using the
default Whonix-Gateway `sys-whonix`, it requires some fixes, follow
[upstream guide](https://www.whonix.org/wiki/Multiple_Whonix-Workstation#Qubes-Whonix)
for the latest version.

- fix qrexec destination of sdwdate:
```sh
## just testing
user@bitcoin-server:~$ sudo mkdir -p /usr/local/etc/sdwdate-gui.d
user@bitcoin-server:~$ echo gateway=sys-bitcoin \
  | tee /usr/local/etc/sdwdate-gui.d/50_user.conf
```

### Clone Bitcoin Core

- switch to the user bitcoin and change to home directory:
```sh
user@bitcoin-server:~$ sudo -H -u bitcoin bash
bitcoin@bitcoin-server:/home/user$ cd
bitcoin@bitcoin-server:~$
```

- clone the bitcoin git repository:
```sh
bitcoin@bitcoin-server:~$ git clone https://github.com/bitcoin/bitcoin /home/bitcoin/bitcoin
```

### Acquire singning keys

- enter the bitcoin directory and receive the signing keys:
<!-- TODO better checking method
it is retrieving the keys using the base a possibly compromised repo
-->
```sh
bitcoin@bitcoin-server:~$ cd /home/bitcoin/bitcoin
bitcoin@bitcoin-server:~/bitcoin$ gpg --recv-keys $(cat contrib/verify-commits/trusted-keys)
```

### Verify software

- verify the tag you want to checkout (e.g.: v23.0) (expect `Good signature`),
  do not procede otherwise.
```sh
bitcoin@bitcoin-server:~/bitcoin$ version="v23.0"
bitcoin@bitcoin-server:~/bitcoin$ git verify-tag ${version}
```

- checkout tag:
```sh
bitcoin@bitcoin-server:~/bitcoin$ git checkout ${version}
```

### Build Bitcoin Core

- build Berkeley DB
  - BDB is necessary for Joinmarket wallet compatibility and some other wallets
    that connect to bitcoin core such as Sparrow.
  - download to home directory to keep binaries after changing git branch
```sh
bitcoin@bitcoin-server:~/bitcoin$ ./contrib/install_db4.sh ${HOME}
bitcoin@bitcoin-server:~/bitcoin$ export BDB_PREFIX="${HOME}/db4"
```

- generate the configure script with autogen:
```sh
bitcoin@bitcoin-server:~/bitcoin$ ./autogen.sh
```

- configure the build (note the configure options are just an example):
  - BDB variables are only necessary if you build the database above.
```sh
bitcoin@bitcoin-server:~/bitcoin$ ./configure --prefix=/home/bitcoin/build \
  BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" \
  BDB_CFLAGS="-I${BDB_PREFIX}/include"
```

- build and install:
```sh
bitcoin@bitcoin-server:~/bitcoin$ make && make install
```

- return to home directory:
```sh
bitcoin@bitcoin-server:~/bitcoin$ cd
bitcoin@bitcoin-server:~$
```

### Configure Bitcoin Core

Note: if using an external drive to hold the blockchain, mount it to
`/home/bitcoin/.bitcoin`.

- create bitcoin data and configuration directory:
```sh
bitcoin@bitcoin-server:~$ mkdir -m 0700 /home/bitcoin/.bitcoin
```

- add configuration to the bitcoin configuration file:
  - insert qube gateway by what qubesdb provides
  - some options are not necessary as they are using default values, it is
    just to make them explicit and enforced in case the default changes value.
```sh
bitcoin@bitcoin-server:~$ qube_gateway="$(qubesdb-read /qubes-gateway)"
bitcoin@bitcoin-server:~$ echo "
##### main #####
datadir=/home/bitcoin/.bitcoin
bind=0.0.0.0:8333
server=1
txindex=1

##### privacy #####
## proxyrandomize helps stream isolation via IsolateSOCKSAuth
proxyrandomize=1
## onlynet paired to only onion outbound connections
onlynet=onion
## proxy for non onion connections
proxy=${qube_gateway}:9400
## onion proxy
onion=${qube_gateway}:9401

##### security #####
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
" | tee -a /home/bitcoin/.bitcoin/bitcoin.conf
```

- lower the bitcoin configuration file permission for only the bitcoin user to
have read and write permissions:
```sh
bitcoin@bitcoin-server:~$ chmod 0600 /home/bitcoin/.bitcoin/bitcoin.conf
```

### Configure bitcoin daemon systemd service

- create a persistent directory.
```sh
user@bitcoin-server:~$ sudo mkdir -m 0700 /rw/config/systemd
```

- paste the following to `/rw/config/systemd/bitcoind.service`:
```systemd
[Unit]
Description=Bitcoin daemon
Documentation=https://github.com/bitcoin/bitcoin/blob/master/doc/init.md
ConditionPathExists=/home/bitcoin/bin/bitcoind
ConditionPathExists=/home/bitcoin/.bitcoin/bitcoin.conf
After=qubes-sysinit.service

[Service]
## Make sure the config directory is readable by the service user
PermissionsStartOnly=true
ExecStartPre=/bin/chgrp bitcoin /home/bitcoin/.bitcoin
## Indicate the conf, the other options will be read from the conf
ExecStart=/home/bitcoin/bin/bitcoind -conf=/home/bitcoin/.bitcoin/bitcoin.conf
ExecStop=/home/bitcoin/bin/bitcoin-cli stop

## directory creation and permissions
User=bitcoin

## process management
Type=forking
Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600

## Provide a private /tmp and /var/tmp.
PrivateTmp=true
## Mount /usr, /boot/ and /etc read-only for the process.
ProtectSystem=full
## Disallow the process and all of its children to gain
## new privileges through execve().
NoNewPrivileges=true
## Use a new /dev namespace only populated with API pseudo devices
## such as /dev/null, /dev/zero and /dev/random.
PrivateDevices=true
## Deny the creation of writable and executable memory mappings.
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
```

- lower the permissions of the bitcoind systemd service:
```sh
user@bitcoin-server:~$ sudo chmod 0600 /rw/config/systemd/bitcoind.service
```

### Misc hardening

- block torbrowser from starting in this qube:
  - if you want to surf, use another VM.
```sh
user@bitcoin-server:~$ sudo mkdir -p -m 700 /usr/local/etc/torbrowser.d
user@bitcoin-server:~$ echo "tb_no_start=true" \
| sudo tee -a /usr/local/etc/torbrowser.d/50_user.conf
```

### Configure boot script

- start service after boot by applying it with `/rw/config/rc.local`:
  - update gateway proxy host
  - copy manpages to path
```sh
user@bitcoin-server:~$ echo '
## update proxy host in case gateway ip changes
## not updating proxy port
## one case the gw ip change is when renaming it
qube_gateway="$(qubesdb-read /qubes-gateway)"
bitcoin_conf="/home/bitcoin/.bitcoin/bitcoin.conf"
if test -f "${bitcoin_conf}"; then
  sed -i "s|onion=.*:|onion=${qube_gateway}:|" "${bitcoin_conf}"
  sed -i "s|proxy=.*:|proxy=${qube_gateway}:|" "${bitcoin_conf}"
fi

## copy man pages to path
cp -r /home/bitcoin/share/man/man1 /usr/share/man

## apply systemd configuration
cp /rw/config/systemd/* /lib/systemd/system/
systemctl daemon-reload
for service in /rw/config/systemd/*; do
  systemctl restart ${service##*/}
done
' | tee -a /rw/config/rc.local
```

- start bitcoind:
```
user@bitcoin-server:~$ sudo /rw/config/rc.local
```

## Listen for incoming connections

You may strenghten the network by listening for incoming connection and
relaying blocks to the P2P network.

### Gateway setup

The following steps should be performend on the Whonix-Gateway AppVM
`sys-bitcoin`:

#### Configure onion-grater

- add onion-grater profile:
```sh
user@sys-bitcoin:~$ sudo onion-grater-add bitcoind
```

- restart onion-grater to apply changes:
```sh
user@sys-bitcoin:~$ sudo systemctl restart onion-grater
```

### Workstation setup

The following steps should be performend on the Whonix-Workstation AppVM
`bitcoin-server`:

#### Bitcoind listening configuration

- configure bitcoind onion listening port:
```sh
echo "
## listen for incoming connections on onion
listen=1
bind=0.0.0.0:8334=onion
" | sudo -u bitcoind tee -a /home/bitcoin/.bitcoin/bitcoin.conf
```

- restart bitcoind to apply changes:
```sh
user@bitcoin-server:~$ sudo systemctl restart --no-block bitcoind
```

#### Configure Workstation firewall

- configure firewall to open port 8334 for incoming tor connections from the
  bitcoin P2P network:
```sh
user@bitcoin-server:~$ sudo mkdir -m 0755 /usr/local/etc/whonix_firewall.d
user@bitcoin-server:~$ echo 'EXTERNAL_OPEN_PORTS+=" 8334 "' \
| sudo tee -a /usr/local/etc/whonix_firewall.d/50_user.conf'
```

- restart firewall service:
```sh
user@bitcoin-server:~$ sudo whonix_firewall
```

## Miscellaneous tips

### Create Alias

In order to control bitcoin with ease:
```sh
user@bitcoin-server:~$ echo 'alias bitcoin-cli="sudo -u bitcoin bitcoin-cli"' \
  | tee -a /home/user/.bashrc
user@bitcoin-server:~$ source /home/user/.bashrc
```

### Get the whitepaper

The Bitcoin whitepaper was encoded to the blockchain in hexadecimal, via
changing `scriptPubKey` of transaction outputs.

```
Block number: 230009
Block hash: 00000000000000ecbbff6bafb7efa2f7df05b227d5c73dca8f2635af32a2e949
Mined Date: 20130604
Transaction ID: 54e48e5f5c656b26c3bca14a8c95aa583d07ebe84dde3b7dd4a78f4e4186e713
```

#### Retrieve the whitepaper from your own blockchain

You can retrieve the whitepaper via various methods:

- **getblock**:
```sh
user@bitcoin-server:~$ bitcoin-cli getblock 00000000000000ecbbff6bafb7efa2f7df05b227d5c73dca8f2635af32a2e949 0 \
  | tail -c+92167 \
  | for ((o=0;o<946;++o)) ; do read -rN420 x ; echo -n ${x::130}${x:132:130}${x:264:130} ; done \
  | xxd -r -p \
  | tail -c+9 \
  | head -c184292 > ~/bitcoin.pdf
```

- **getrawtransaction**:
```sh
user@bitcoin-server:~$ bitcoin-cli getrawtransaction 54e48e5f5c656b26c3bca14a8c95aa583d07ebe84dde3b7dd4a78f4e4186e713 0 00000000000000ecbbff6bafb7efa2f7df05b227d5c73dca8f2635af32a2e949 \
  | sed 's/0100000000000000/\n/g' \
  | tail -n +2 \
  | cut -c7-136,139-268,271-400 \
  | tr -d '\n' \
  | cut -c17-368600 \
  | xxd -p -r > ~/bitcoin.pdf
```

- **gettxout** (slow as hell):
```sh
user@bitcoin-server:~$ seq 0 947 \
  | (while read -r n; do bitcoin-cli gettxout 54e48e5f5c656b26c3bca14a8c95aa583d07ebe84dde3b7dd4a78f4e4186e713 $n \
  | jq -r '.scriptPubKey.asm' \
  | awk '{ print $2 $3 $4 }'; done) \
  | tr -d '\n' \
  | cut -c 17-368600 \
  | xxd -r -p > ~/bitcoin.pdf
```

#### Convert the whitepaper from PDF to text

It is also possible the pdf to text to read on headless machines:
```sh
user@bitcoin-server:~$ pdftotext ~/bitcoin.pdf
```
Read the file with less:
```
user@bitcoin-server:~$ less ~/bitcoin.txt
```

#### Convert the whitepaper from PDF to RGP bitmap

Or you can convert the pdf to a safe-to-view RGB bitmap:
```sh
user@bitcoin-server:~$ qvm-convert-pdf ~/bitcoin.pdf
```
Note that it will not be possible anymore to convert the `bitcoin.trusted.pdf` to
text, as it became a image and not translatable to text.
