# Electrum Client

## Table of Contents
<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
  * [Program description](#program-description)
  * [Qubes Design](#qubes-design)
  * [Why Qubes-Whonix](#why-qubes-whonix)
  * [Should I use third-party servers with this method?](#should-i-use-third-party-servers-with-this-method)
  * [Bitcoin keys security](#bitcoin-keys-security)
* [Dom0 setup](#dom0-setup)
  * [Create Whonix-Workstation AppVM](#create-whonix-workstation-appvm)
* [Whonix-Workstation DispVM](#whonix-workstation-dispvm)
  * [Download electrum](#download-electrum)
* [Whonix-Workstation AppVM](#whonix-workstation-appvm)
  * [Install electrum](#install-electrum)
* [Dom update wallet menu items](#dom-update-wallet-menu-items)
* [Using cold storage with the command line](#using-cold-storage-with-the-command-line)
  * [Create an unsigned transaction](#create-an-unsigned-transaction)
  * [Sign the transaction](#sign-the-transaction)
  * [Broadcast the transaction](#broadcast-the-transaction)

<!-- vim-markdown-toc -->

## Overview

### Program description

[Electrum](https://electrum.org) or electrum-client, is a lightweight Bitcoin
wallet that speaks the [electrum protocol](https://electrumx-spesmilo.readthedocs.io/en/latest/protocol.html)
with electrum servers. The wallet uses a technique called [SPV](https://electrum.readthedocs.io/en/latest/spv.html#spv)
(Simple Payment Verification) to verify that a transaction is included in the
blockchain without the need to download the entire blockchain. The client only
downloads the block headers which are much smaller than the full blocks. To
verify that a transaction is in a block, a SPV client requests a proof of
inclusion, in the form of a Merkle branch.

The guide will be about the [Electrum](https://github.com/spesmilo/electrum)
wallet, but some other honorable mentions are:
- [Sparrow](https://github.com/sparrowwallet/sparrow)

The Electrum client was chosen because it is signed by two or more developers,
has reproducible builds, is one of the oldes bitcoin wallets (2011). Sparrow
has an excellent UI and very recently became reproducible, but the it is much
less reviewed and the [pull-down menus don't work on Qubes](https://github.com/sparrowwallet/sparrow/issues/170),
which has some workarounds descriped on the comments of the above issue but
still degrades the user experience.

### Qubes Design

The `electrum-client` that will be created is a non-networked qube with port
binding from the `electrum-server` created from the step before. It is a wallet
responsible for managing bitcoin UTXOs, allowing the user to make unsigned,
partially-signed and signed transactions without connecting to the user facing
internet, but connecting to the bitcoin network via the electrum server.

### Why Qubes-Whonix

Qubes is necessary for the electrum-client to be isolated from other activities
on its own qube. As the wallet is on a dedicated non-networked qube, the
electrum-server is neither hosted on the same virtual machine as the wallet nor
interacting with the wallet on LAN or through the internet, which is the
default for online wallets. Qubes enforces the virtual machine to no be
networked and allows binding of the electrum-server port to the electrum-client
qube on localhost.

With this setup, you have all the benefits of a online wallet such as seeing
its balance, (un)confirmed transactions, broadcasting transactions, without
the drawbacks of normal online wallets that use multiple applications on the
same machine which leads to a higher attack surface and malware could steal
the bitcoin keys.

There is no networking, so Whonix is not necessary to be the guest operating
system. Whonix was chosen because it has the Electrum wallet pre-installed.
Debian could also be used. This does not regard Kicksecure hardening to Whonix
base which are pretty minimized on Qubes OS.

### Should I use third-party servers with this method?

No, you should not, it is not secure to use third party electrum servers with
this method because it poses a higher security risk as the SPV method can not
work with this design. If you don't have your own server, you are better off
using a dedicated Whonix-Workstation qube networked and connected to random
servers (less private) or start running your own server if you desire greater
privacy and security.

As the client can't connect to other services to subscribe to block header
notifications, the wallet is solely trusting the information delivered by the
third-party server, wheter its is lagging, splitting the chain or forking. The
SPV method can not be executed because it does not have a minimum number of
servers to verify the information against the main server, as there is only one
source you are connected to.

Read more about [potention SPV weaknessses](https://developer.bitcoin.org/devguide/operating_modes.html#potential-spv-weaknesses).

### Bitcoin keys security

The paragraphs above only mentioned "bitcoin keys", not specifying if they are
the private or public part of the key pair, it is intentional, the user will
decide based on their own studies, what part of the key pair they will use with
this setup. This is not an in depth discussion, it is just the basics.

As a general rule, private keys should be stored on cold (offline) storage,
because it greatly diminishes the attack surface of internet facing malware.

Should you decide to store the private key on a cold virtualized storage such
as Qubes OS with the `electrum-client` qube or on a physically isolated machine
normally referred as an `air gapped` system, every method has drawbacks.

1. storing the private key safely
  - encrypted or on a live amnesic system
  - without easy access to anyone, either by geo-location or hidden
2. secure means of transferring data between security domains
  - from the less trusted to the more trusted domain, when transferring a
    transaction from a external system to the cold system to be signed
  - from the more trusted domain to the less trusted domain, when transferring
    a signed transaction from the cold system to be used on the external system

Storing the private keys on a air gapped system is very easy, the keys can be
created on the cold system and stay there or disappear upon shutdown. Transfer
of files between different security domains is very tricky. The attack surface
of USB is immense, your camera could be spying on you, the network should not
be trusted nor used, radio frequency is not encrypted and all of this means of
transfer means that data can also be exfiltrated from the air gapped system
through them.

QubesOS provides secure tools to communicate data between domains, most common
ones are inter-VM File Copy and inter-VM clipboard. When using those programs,
there is no USB, nor camera, nor radio signal used in those qubes, therefore
not dealing with a lot of complicated and code that could expose higher risks
or normal systems, but isolated on Qubes by UsbVMs, that holds the backend of
the USB PCI bus devices.

We recommend reading former QubesOS developer, Joanna Rutkowska's paper about
[Software compartmentalization vs physical separation](https://invisiblethingslab.com/resources/2014/Software_compartmentalization_vs_physical_separation.pdf).

## Dom0 setup

### Create Whonix-Workstation AppVM

- create Whonix-Workstation AppVM non-networked and name it `electrum-client`:
```sh
[user@dom0]$ qvm-create electrum-client \
  --template whonix-ws-16 \
  --label orange \
  --prop netvm="" \
  --prop maxmem="700" \
  --prop vcpus="1"
```

- allow communication from the `electrum-server` port to the `electrum-client`:
```sh
[user@dom0]$ echo "
qubes.ConnectTCP +50001 electrum-client @default allow target=electrum-server
" | tee -a /etc/qubes/policy.d/80-qwbtc.policy
```

- run terminal in disposable qube based on main Whonix DVM Template:
  - it will be used for downloading the software for the non-networked qube
  - will be referred as `disp1111` in the following chapter
```sh
[user@dom0]$ qvm-run \
  --dispvm whonix-ws-16-dvm
  --service qubes.StartApp+qubes-run-terminal
```

## Whonix-Workstation DispVM

### Download electrum

Electrum is available on Debian repos and at the moment of writing, comes
pre-installed to Whonix-Workstation. The issue is that new versions takes
months to become available. At the following moment, electrum has not stopped
releasing upstream, but the Debian build is more than a year old.

We tried to build electrum following the same build process made by debian,
that is hosted on [salsa](https://salsa.debian.org/cryptocoin-team/electrum),
but unfortunately, not all dependencies available on Debian Stable are
compatible with electrum requirements, making the client not even start.
The Debian Testing repo does not contain newer versions of electrum, but it
satisfies all dependencies.

Because building the debian package using the testing repos and hoping the
dependencies are met with the right version is complex, it is not an
alternative.
.
Current electrum version is `4.3.2`, adapt the version when necessary.

Steps to be executed on the newly created disposable `disp1111`.

- set software version, url and package to be downloaded. Download the package
  and its signature.
```sh
user@disp1111:~$ version="4.3.2"
user@disp1111:~$ url="https://download.electrum.org/${version}"
user@disp1111:~$ package="electrum-${version}-x86_64.AppImage"
user@disp1111:~$ scurl-download "${url}/${package}"
user@disp1111:~$ scurl-download "${url}/${package}.asc"
```

- download the maintainer's (Thomas Voegtlin and Sombernight) public key:
  - source: [electrum site about page](https://electrum.org/#about)
  - source: [2016 youtube video](https://www.youtube.com/watch?v=hjYCXOyDy7Y)
  - source: [keys.gnupg.net](http://keys.gnupg.net/pks/lookup?search=0x6694D8DE7BE8EE5631BED9502BD5824B7F9470E6&fingerprint=on&op=index)
  - source: [github repo](https://github.com/spesmilo/electrum/master/pubkeys)
```sh
user@disp1111:~$ scurl-download \
 https://raw.githubusercontent.com/spesmilo/electrum/master/pubkeys/ThomasV.asc
user@disp1111:~$ scurl-download \
 https://raw.githubusercontent.com/spesmilo/electrum/master/pubkeys/sombernight_releasekey.asc
```

- copy the files to `electrum-client`, select it from the dom0 popup:
  - we are not verifying the files on this machine because it is untrusted,
    it is just a disposable to download files
```sh
user@disp1111:~$ qvm-copy ${package} ${package}.asc ThomasV.asc sombernight_releasekey.asc
```

## Whonix-Workstation AppVM

### Install electrum

Steps to be done on the qube hosting the wallet called `electrum-client`.

- safely remove the electrum debian package:
  - this step is done to avoid issues with Whonix meta package removal
  - before confirming the purge, verify that the Whonix meta packages are not
    being removed, only the electrum package should be
```sh
user@electrum-client:~$ sudo apt update
user@electrum-client:~$ sudo apt install dummy-dependency-electrum
user@electrum-client:~$ sudo apt purge electrum
```

- move the imported files form the disposable to the home directory of
  `electrum-client`:
```sh
user@electrum-client:~$ mv ~/QubesIncoming/disp1111/* ~/
```

- verify Thomas public key before importing:
  - above many sources of the key was provided, you mut expect the fingerprint
    to be exactly: `6694 D8DE 7BE8 EE56 31BE D950 2BD5 824B 7F94 70E6`. If not
    matching, do not procede.
```sh
user@electrum-client:~$ gpg --keyid-format long --with-fingerprint \
  --import --import-options show-only ThomasV.asc
```

- import Thomas's key:
```
user@electrum-client:~$ gpg --import ThomasV.asc
```

- verify Sombers's public key before importing:
  - above many sources of the key was provided, you must expect the fingerprint
    to be exactly: `0EED CFD5 CAFB 4590 6734 9B23 CA9E EEC4 3DF9 11DC`. If not
    matching do not procede.
```sh
user@electrum-client:~$ gpg --keyid-format long --with-fingerprint \
  --import --import-options show-only sombernight_releasekey.asc
```

- import sombernight's key:
```
user@electrum-client:~$ gpg --import sombernight_releasekey.asc
```

- verify the downloaded package and expect `Good signature` from both
  maintainers:
```sh
user@electrum-client:~$ version="4.3.2"
user@electrum-client:~$ gpg --verify electrum-${version}-x86_64.AppImage.asc
```

- make the package executable:
```sh
user@electrum-client:~$ chmod +x electrum-${version}-x86_64.AppImage
```

- symlink the package to the `/usr/local/bin` to precede on PATH relative to
  electrum installed of debian packkage on `/usr/bin`:
```sh
user@electrum-client:~$ sudo ln -sf \
  /home/user/electrum-${version}-x86_64.AppImage /usr/local/bin/electrum
```

- connect the electrum-client to the electrum-server via qrexec:
```sh
user@electrum-client:~$ echo "qvm-connect-tcp ::50001" \
  | tee -a /rw/config/rc.local
```

- execute the startup file to establish the connection:
```sh
user@electrum-client:~$ sudo /rw/config/rc.local
```

- create electrum data directory:
```sh
user@electrum-client:~$ mkdir -m 0700 ~/.electrum
```

- create electrum configuration:
  - expect `true` as reply from every command, meaning the confiuration was set
  - only connect to one server, in this case `electrum-server`
  - do not check for updates, it wouldn't work because the qube has no netvm
  - show relevant tabs such as addresses, contacts, utxo
  - hide irrelevant tabs such as channels
  - hide console for a tiny bit of security
```sh
user@electrum-client:~$ electrum --offline setconfig auto_connect false
user@electrum-client:~$ electrum --offline setconfig check_updates false
user@electrum-client:~$ electrum --offline setconfig oneserver true
user@electrum-client:~$ electrum --offline setconfig server 127.0.0.1:50001:t
```

- lower electrum configuration files permissions:
```sh
user@electrum-client:~$ chmod 600 ~/.electrum/config
```

- start electrum wallet:
```sh
user@electrum-client:~$ electrum
```

- create desktop shortcut:
  - only necessary if not using the debian package
```sh
user@electrum-client:~$ mkdir -p ~/.local/share/applications
user@electrum-client:~$ echo '
[Desktop Entry]
Comment=Lightweight Bitcoin Client
Exec=sh -c "PATH=\"\\$HOME/.local/bin:\\$PATH\"; electrum %u"
GenericName[en_US]=Bitcoin Wallet
GenericName=Bitcoin Wallet
Icon=money-manager-ex
Name[en_US]=Electrum Bitcoin Wallet
Name=Electrum Bitcoin Wallet
Categories=Finance;Network;
StartupNotify=true
StartupWMClass=electrum
Terminal=false
Type=Application
MimeType=x-scheme-handler/bitcoin;
Actions=Testnet;

[Desktop Action Testnet]
Exec=sh -c "PATH=\"\\$HOME/.local/bin:\\$PATH\"; electrum --testnet %u"
Name=Testnet mode
' | tee ~/.local/share/applications/electrum.desktop
```

- autostart electrum application on qube boot:
```sh
user@electrum-client:~$ mkdir -p ~/.config/autostart
```

  - if using the above configured desktop file:
```sh
user@electrum-client:~$ ln -s \
  ~/.local/share/applications/electrum.desktop ~/.config/autostart/
```

  - if using the debian packaged desktop file:
```sh
user@electrum-client:~$ ln -s \
  /usr/share/applications/electrum.desktop ~/.config/autostart/
```

## Dom update wallet menu items

On `dom0`

- set only relevant menu items for `electrum-client`:
```sh
[user@dom0 ~]$ qvm-features electrum-client menu-items "electrum.desktop org.gnone.Nautilus.desktop xfce4-terminal.desktop"
```

- update app menus:
```sh
[user@dom0 ~]$ qvm-appmenus --update --force electrum-client
```

- or via GUI, refresh `electrum-client` qube appmenu and and desktop shortcut:
  - `Qube Manager` -> `electrum-client` -> `App shortcuts` ->
    `Refresh applications` -> select `electrum` and click on `>` to pass app
    to be on the menu and click on `Ok` to apply can close app shortcuts
  - now you can either start the qube or click on the electrum shortcut to
    start the electrum wallet.

## Using cold storage with the command line

The command line may suit you best, and if you are already here, then you have
already done most of the hard work on the terminal, read [cli electrum docs](https://electrum.readthedocs.io/en/latest/coldstorage_cmdline.html).
This is what will be presented below.

If you prefer the graphical interface version, it is also available on the
[electrum docs](https://electrum.readthedocs.io/en/latest/coldstorage.html),
but won't be presented here.

We understand that some people might still prefer air gapped hosts, below is
explained how to sign on air gapped host. Even though the commands do not
differ from the electrum documentation, we changed the hostname to facilitate
reading and moved the deserialized section to be done on the air gapped machine
before the signing process.

### Create an unsigned transaction

Steps to be done on the machine containing the master public key, in our case,
the `electrum-client`.

With your online (watching-only) wallet, create an unsigned transaction:
```sh
user@electrum-client:~$ electrum payto ADDRESS AMOUNT --unsigned > unsigned.txn
```
The unsigned transaction is stored in a file named `unsigned.txn`. Note that
the --unsigned option is not needed if you use a watching-only wallet.

### Sign the transaction

Steps to be done on the machine containing the master private key, in this
case, your air gapped machine.

Before signing the transaction, you may view it deserialized using:
```sh
user@AIR_GAP_HOST:~$ electrum deserialize $(cat unsigned.txn)
```

The serialization format of Electrum contains the master public key needed and
key derivation, used by the offline wallet to sign the transaction.

Thus we only need to pass the serialized transaction to the offline wallet:
```sh
user@AIR_GAP_HOST:~$ electrum signtransaction $(cat unsigned.txn) > signed.txn
```

The command will ask for your password, and save the signed transaction in
`signed.txn`.

### Broadcast the transaction

Steps to be done on the networked machine, in our case, the `electrum-client`.

Make sure that you signed the intended transaction before broadcasting:
```sh
user@electrum-client:~$ electrum deserialize $(cat signed.txn)
```

Send your transaction to the Bitcoin P2P network using `broadcast`:
```sh
user@electrum-client:~$ electrum broadcast $(cat signed.txn)
```

If succesful, the command will return the TXID (Transaction ID).
