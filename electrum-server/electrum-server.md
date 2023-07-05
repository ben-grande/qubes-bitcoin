# Electrum Server

## Table of Contents
<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
  * [Program description](#program-description)
  * [Qubes design](#qubes-design)
  * [Why Qubes-Whonix](#why-qubes-whonix)
  * [Why use an Electrum Server](#why-use-an-electrum-server)
* [Dom0 setup](#dom0-setup)
  * [Clone Template](#clone-template)
  * [Create AppVMs](#create-appvms)
    * [Create Whonix-Workstation AppVm](#create-whonix-workstation-appvm)
    * [Create Whonix-Gateway AppVm](#create-whonix-gateway-appvm)
  * [Resize server private volume](#resize-server-private-volume)
* [Template Setup](#template-setup)
  * [Install dependencies](#install-dependencies)
  * [Create server user](#create-server-user)
  * [Power off the template](#power-off-the-template)
* [Setup Bitcoin RPC on the bitcoind VM](#setup-bitcoin-rpc-on-the-bitcoind-vm)
  * [Generate RPC credentials](#generate-rpc-credentials)
  * [Include credentials to the bitcoin configuration file](#include-credentials-to-the-bitcoin-configuration-file)
  * [Enable publish hash block](#enable-publish-hash-block)
  * [Restart bitcoind](#restart-bitcoind)
* [Application setup](#application-setup)
  * [Fix Multiple Qubes Whonix-Workstation](#fix-multiple-qubes-whonix-workstation)
  * [Prepare static linked binaries](#prepare-static-linked-binaries)
  * [Clone Fulcrum](#clone-fulcrum)
  * [Receive signing keys](#receive-signing-keys)
  * [Verify software](#verify-software)
  * [Build fulcrum](#build-fulcrum)
  * [Fill authorizations for the electrum server via RPC cookie](#fill-authorizations-for-the-electrum-server-via-rpc-cookie)
  * [Electrum server configuration](#electrum-server-configuration)
  * [Configure electrum server systemd service](#configure-electrum-server-systemd-service)
  * [Misc hardening](#misc-hardening)
  * [Configure boot script](#configure-boot-script)
* [Finish](#finish)
* [Make the electrum server reachable via tor](#make-the-electrum-server-reachable-via-tor)
  * [Whonix-Gateway AppVM dedicated to electrum server actions:](#whonix-gateway-appvm-dedicated-to-electrum-server-actions)
  * [Whonix-Workstation AppVM dedicated to electrum server actions:](#whonix-workstation-appvm-dedicated-to-electrum-server-actions)

<!-- vim-markdown-toc -->

## Overview

### Program description

The electrum server indexes the bitcoin blockchain and the result index enables
fast queries for any wallet that electrum protocol compatible wallet, thus
allowing to user to keep real-time track of balances and transaction history
using the electrum client (wallet).

The guide will be about [Fulcrum](https://github.com/cculianu/Fulcrum) Electrum
Server, but some honorable mentions are:
- [ElectRS](https://github.com/romanz/electrs)
- [ElectrumX](https://github.com/spesmilo/electrumx)
- [Electrum-Personal-Server](https://github.com/chris-belcher/electrum-personal-server)
- [BWT](https://github.com/bwt-dev/bwt)

Note that privacy wise, projects such as Fulcrum, ElectRS, ElectrumX, are
better because they store a full address index, not keeping remaining addresses
on the server after the client/wallet closes. This comes with the disadvantage
of needing a higher storage capacity.

On the other hand, BWT and Electrum Personal Server must store addresses for
every wallet provided to them, not storing full blockchain address index,
making the server more lightweight but also slower on queries. If the server
ever gets hacked, more private information such as all addresses of the client
will leak. It is still better privacy-wise to use your own server rather than
third-party servers.

If you are interested in electrum servers performance comparisons, we recommendreading [benchmarks](https://sparrowwallet.com/docs/server-performance.html)
made by Sparrow wallet maintainer, Craig Raw, last updated 2022-02-01.

Fulcrum is the fastest electrum server implementation to reply user quries, but
it also consumes a lot more memory, CPU and storage then every other server. It
also lacks a good method to find which block the server was analyzing when it
was forcefully killed, thus leading to a corrupt database and needing to delete
the entire database and reindex it again. Note this has a higher chance of
happening during initial sync and the upstream maintainers have plans on fixing
this issue. Fulcrum's address index database size at 2022-10 is at 120GB.

### Qubes design

The `electrum-server` qube is a non-networked qube that holds the bitcoin
blockchain indexed by address. It will be connected to the `electrum-client` in
the next step over localhost. Optionally, if you want to make the server
available over externally over tor you can enable networking and creating an
onion service on the Whonix-Gateway.

### Why Qubes-Whonix

Qubes allows via qrexec policy for the electrum-server qube to connect to the
bitcoin-server bitcoind's RPC port on localhost, therefore limiting the
hazard the electrum server could do to the bitcoind by being on hosted on the
same machine, while not relying on insecure transports over untrusted network
to sniff the JSON-RPC credentials, as they are not encrypted.

Whonix was chosen as guest because it can host an onion service on a different
machine than the electrum server. It also does enforce all traffic through tor
and has stream isolation configured by default for all systems applications
that we are going to use, such as `apt`, `git`, `gpg`. Note that we are not
announcing our service via electrum configuration, but we can optionally create
an onion service on the Whonix-Gateway for it to be reacheable by our remote
clients.

### Why use an Electrum Server

We consider the Bitcoin Core the least trusted domain, although it is our only
connection to the Bitcoin network, it is also a networked qube running a server
daemon 24/7 that can optionally receive incoming connections.

Every wallet connecting directly to the Bitcoin Core RPC must have the wallet
RPC calls whitelisted for them to work, but there is not native bitcoin daemon
filtering of wallets that RPC users can access. This means that every user with
the wallet RPC calls whitelisted can run that available commands for every
wallet, indepdently if it was created by that user or not. Bitcoin Core stores
wallet public keys and balance unencrypted on the host it is running on, in our
case the `bitcoin-server` qube. Not only RPC users can see you public keys and
your balance, this qube is the most vulneable being at risk of attackers, which
if they succeed, they can target you depending on their interest.

In contrast, the electrum server hosted on the `electrum-server` qube will not
keep any record of your balance, it will index all transaction equally. This
qube also does not require wallet RPC calls, as it is only an indexer and won't
user Bitcoin Core's wallet functionalities. Although it requires more disk
space to index addresses, with security and privacy in mind, it is worth it.

It is also more secure for the provider (you) to share an Electrum Server with a
third party, family, friends, random person on the internet than to give them
Bitcoin Core's RPC credentials, which requires special care to whitelist the
RPC calls and requires wallets commands whitelisted.

## Dom0 setup

Note: creating a Whonix-Gateway for the Electrum Server is only necessary if
you want to make your server available via tor. If you only plan to use
an electrum server with an electrum wallet running on a qube on the same
computer, skip this step and set `--prop netvm=''` when creating the
Whonix-Workstation, plus the networked actions of the Whonix-Workstation needs
to be done on a separate disposable qube and then move the files with
`qvm-move`. The burden is that a considerably large git repository will have
to be downloaded and moved for every update.

### Clone Template

- clone Whonix-Workstation TemplateVM and name it
`whonix-ws-16-electrum-server`.
```sh
[user@dom0]$ qvm-clone whonix-ws-16 whonix-ws-16-electrum-server
```

### Create AppVMs

#### Create Whonix-Workstation AppVm

- create Whonix-Workstation AppVM and name it `electrum-server`:
  - fulcrum is memory and cpu hungry, you can lower those values after the
    initial sync is complete.
  - once the transaction index in the bitcoind is built, CPU and RAM will have
    the greater influence on fulcrum building the address index, so the more
    memory you assign during the first sync, the faster it will be. After first
    sync, it can be lowered to `1200`, but remember to also lower the memory
    assigned to Fulcrum's database `db_mem` on `fulcrum.conf` to 75% of total
    memory.
```sh
[user@dom0]$ qvm-create electrum-server \
  --template whonix-ws-16-electrum-server \
  --label red \
  --prop netvm="sys-bitcoin" \
  --prop memory="600"
  --prop maxmem="5000" \
  --prop vcpus="2"
```

#### Create Whonix-Gateway AppVm

- create Whonix-Workstation AppVM and name it `bitcoin-untrusted`:
  - this qube will serve to download files and transfer to non-networked qubes.
```sh
[user@dom0]$ qvm-create bitcoin-untrusted \
  --template whonix-ws-16 \
  --label red \
  --prop netvm="sys-bitcoin" \
  --prop maxmem="500" \
  --prop vcpus="1"
```

### Resize server private volume

- resize `electrum-server` private volume size:
  - if using a usb to hold the electrum database, rezise the private volume to
    `10G` so it has space for the build.
```sh
[user@dom0]$ qvm-volume resize electrum-server:private 150G
```

- set tag to facilitate setting qrexec rules:
  - UpdatesProxy rules were set on the bitcoin-server guide.
```sh
[user@dom0]$ qvm-tags whonix-ws-16-electrum-server set bitcoin-updatevm
```

- allow communication from the bitcoind VM `bitcoin-server` to the electrum
  server VM `electrum-server` to access the Bitcoind RPC and ZMQ
  ports:
```sh
[user@dom0]$ echo "
qubes.ConnectTCP +8332 electrum-server @default allow target=bitcoin-server
qubes.ConnectTCP +8433 electrum-server @default allow target=bitcoin-server
" | tee -a /etc/qubes/policy.d/80-qwbtc.policy
```

Get `electrum-server` Qube IP to substitue `<electrum-server-qube-ip>` in later examples:
```sh
[user@dom0]$ qvm-prefs electrum-server ip
```

## Template Setup

The following steps should be performed on the Whonix-Workstation TemplateVM
`whonix-ws-16-electrum-server`.

### Install dependencies

- install dependencies (dependencies can be found at the following headers):
  - [building a static executable for linux](https://github.com/cculianu/Fulcrum#building-a-static-executable-for-linux).
  - [requirements](https://github.com/cculianu/Fulcrum#requirements)
  - [how to compile](https://github.com/cculianu/Fulcrum#how-to-compile)
  - [making sure libzmq is detected and used (optional but recommended)](https://github.com/cculianu/Fulcrum#making-sure-libzmq-is-detected-and-used-optional-but-recommended)
  - [Fulcrum/contrib/build/linux/Dockerfile](https://github.com/cculianu/Fulcrum/blob/master/contrib/build/linux/Dockerfile#L14)
```sh
user@whonix-ws-16-electrum-server:~$ sudo apt update -y

user@whonix-ws-16-electrum-server:~$ sudo apt install -y \
  git python3 build-essential cmake qmake6 clang pkg-config \
  qt6-base-dev libzmq3-dev libbz2-dev librocksdb-dev libjemalloc-dev \
  zlib1g-dev libssl-dev libnss3-dev libxslt1-dev libxml2-dev libzstd-dev \
  libgssapi-krb5-2 libpgm-dev libsodium-dev libsnappy-dev liblz4-dev

user@whonix-ws-16-electrum-server:~$ sudo update-alternatives \
  --install /usr/bin/qmake qmake /usr/bin/qmake6 60
```

### Create server user

Create system user:
```sh
user@whonix-ws-16-electrum-server:~$ sudo adduser --system fulcrum
```

### Power off the template

Shutdown template:
```sh
user@whonix-ws-16-electrum-server:~$ sudo poweroff
```

## Setup Bitcoin RPC on the bitcoind VM

Remote Procedure Call is necessary to interact with the bitcoin daemon from
an external machine.

The following steps should be performed on the Whonix-Workstation AppVM
`bitcoin-server`:

### Generate RPC credentials

- log in as the `bitcoin` user:
```sh
user@bitcoin-server:~$ sudo -H -u bitcoin bash
bitcoin@bitcoin-server:/home/user$ cd
bitcoin@bitcoin-server:~$
```

- from the bitcoin git directory, generate RPC credentials
```sh
bitcoin@bitcoin-server:~$ /home/bitcoin/bitcoin/share/rpcauth/rpcauth.py \
  "$(head -c 15 /dev/urandom | base64)"
```
The output will be in the same format as (warn: do not use the same auth):
```
String to be appended to bitcoin.conf:
rpcauth=7PXaFZ5DLG2alSeiGxnM:9ffa7d78e1ddcb25ace4597bc31a1c8d$541c44f5d34044d532db47b74e9755ca4f0d87f805dd5895f0b36ea3a8d8c84c
Your password:
GKkkKy-GAEDUw_6dp32O7Rh3DhHAnYhBUwNwNWUZPrI=
```
- the first field of `rpcauth` before the `:` colon is the RPC `user`, in
  this case called `7PXaFZ5DLG2alSeiGxnM`.
- the second field of `rpcauth` after the `:` colon is the RPC HMAC-SHA-256
  `hashed password` for JSON-RPC connections, in this case
  `9ffa7d78e1ddcb25ace4597bc31a1c8d$541c44f5d34044d532db47b74e9755ca4f0d87f805dd5895f0b36ea3a8d8c84c`.
- the last line contains the actual `password`, in this case
  `GKkkKy-GAEDUw_6dp32O7Rh3DhHAnYhBUwNwNWUZPrI=`.

### Include credentials to the bitcoin configuration file

- include credentials to bitcoin.conf (replace the user and hashed pass):
  - single quotes are used with echo or printf to escape the `$` char from the
    string.
- whitelist rpc calls for the fulcrum user
```sh
bitcoin@bitcoin-server:~$ echo '## fulcrum auth
rpcauth=<rpc-user>:<hashed-pass>'
  | tee -a /home/bitcoin/.bitcoin/bitcoin.conf
```

### Enable publish hash block

ZeroMQ is a high performance asynchronous messaging library.
It is useful for many concurrent services such as electrum servers.

- enable zmq:
```sh
bitcoin@bitcoin-server:~$ echo "## zmq configuration
zmqpubhashblock=tcp://127.0.0.1:8433" \
  | tee -a /home/bitcoin/.bitcoin/bitcoin.conf
```

### Restart bitcoind

- exit from the `bitcoin` user back to `user` user:
```sh
bitcoin@bitcoin-server:~$ exit
user@bitcoin-server:~$
```

- restart bitcoind to apply new configuration:
```sh
user@bitcoin-server:~$ sudo systemctl restart bitcoind.service
```

## Application setup

The following steps should be performed on the Whonix-Workstation AppVM
`electrum-server`:

### Fix Multiple Qubes Whonix-Workstation

The `bitcoin-server` is connect to `sys-bitcoin`, as we are not using the
default Whonix-Gateway `sys-whonix`, it requires some fixes, follow
[upstream guide](https://www.whonix.org/wiki/Multiple_Whonix-Workstation#Qubes-Whonix)
for the latest version.

- fix qrexec destination of sdwdate:
```sh
user@bitcoin-server:~$ sudo mkdir -p /usr/local/etc/sdwdate-gui.d
user@bitcoin-server:~$ echo gateway=sys-bitcoin \
  | tee /usr/local/etc/sdwdate-gui.d/50_user.conf
```

### Prepare static linked binaries

- build Fulcrum (Fulcrum does not provide a builder without docker, so here are some
  resources to serve as inspiration: [1](https://github.com/cculianu/Fulcrum/blob/master/contrib/build/build.sh) [2](https://github.com/cculianu/Fulcrum/blob/master/contrib/build/linux/_build.sh) [3](https://github.com/cculianu/Fulcrum/blob/master/contrib/build/linux/Dockerfile)
  - add the code below to `/home/user/prepare-fulcrum.sh`:
```sh
#!/usr/bin/env bash

zstd_libdir_orig="$(pkg-config --variable=libdir libzstd)"
rocksdb_libdir_orig="/usr/lib"
pgm_libdir_orig="/usr/lib/x86_64-linux-gnu"
sodium_libdir_orig="$(pkg-config --variable=libdir libsodium)"
snappy_libdir_orig="$(pkg-config --variable=libdir snappy)"
lz4_libdir_orig="$(pkg-config --variable=libdir liblz4)"
jemalloc_libdir_orig="$(pkg-config --variable=libdir jemalloc)"
zmq_libdir_orig="$(pkg-config --variable=libdir libzmq)"

## please match the above variables without '$' to the variable below
all_libdir_orig="zstd_libdir_orig rocksdb_libdir_orig pgm_libdir_orig sodium_libdir_orig snappy_libdir_orig lz4_libdir_orig jemalloc_libdir_orig zmq_libdir_orig"

fulcrum_buildtmp="/tmp/fulcrum-build"

## start with variable empty
all_libdir_target=""
for library in ${all_libdir_orig}; do
  ## get only library name
  lib_name="${library%%_*}"
  ## get libdir path
  tmp_var="$(eval printf '%s' '$'"${lib_name}"_libdir_target)"
  ## assign to _target the library target dir
  eval "${lib_name}"_libdir_target="${fulcrum_buildtmp}/lib/${lib_name}"
  ## save libdir path to all targets to be created and targeted
  all_libdir_target="${all_libdir_target} ${tmp_var}"
done
## unset variable(s)
lib_name=""

mkdir -p ${all_libdir_target}

for dir in ${all_libdir_target}; do
  ## get library name by target path (it does not contain lib prefix)
  lib_name="${dir##*/}"
  ## get library origin directory by evaluation
  eval lib_orig="$(printf '%s' '$'${lib_name}_libdir_orig)"
  ## cp library*.a files to target dir
  cp ${lib_orig}/lib${lib_name}*.a "${dir}"
  ## strip all files present in target dir
  for file in ${dir}/*; do
    strip -g "${file}"
  done
done
```

- do fulcrum preparations:
```sh
user@electrum-server:~$ sudo bash ./prepare-fulcrum.sh
```

### Clone Fulcrum

- switch to user `fulcrum` and change to home directory
```sh
user@electrum-server:~$ sudo -H -u fulcrum bash
fulcrum@electrum-server:/home/user$ cd
fulcrum@electrum-server:~$
```

- clone the [Fulcrum repository](https://github.com/cculianu/Fulcrum)
```sh
fulcrum@electrum-server:~$ git clone https://github.com/cculianu/Fulcrum \
  /home/fulcrum/Fulcrum
```

- enter the cloned git repository:
```sh
fulcrum@electrum-server:~$ cd ~/Fulcrum
```

### Receive signing keys

- receive maintainer Cculianu public key:
```sh
fulcrum@electrum-server:~$ scurl-download https://raw.githubusercontent.com/Electron-Cash/keys-n-hashes/master/pubkeys/calinkey.txt
```

- verify Cculianu's public key before importing:
  - above many sources of the key was provided, you must expect the fingerprint
    to be exactly: `D465 135F 97D0 047E 18E9 9DC3 2181 0A54 2031 C02C`. If not
    matching do not procede.
```sh
fulcrum@electrum-server:~$ gpg --keyid-format long --with-fingerprint \
  --import --import-options show-only sombernight_releasekey.asc
```

### Verify software

- verify the commit to that the tag references (e.g.: tag is `v1.8.1`),
  and expect a `Good signature`:
  - Fulcrum does not have signed tags, only signed commits, this is why
    this method was chosen, to verify the commit the tag references.
```sh
fulcrum@electrum-server:~/Fulcrum$ git verify-commit v1.8.1^{commit}
```

- checkout tag:
```sh
fulcrum@electrum-server:~/Fulcrum$ git checkout v1.8.1
```

### Build fulcrum

- creata build directory and enter it:
```sh
fulcrum@electrum-server:~/Fulcrum$ mkdir build && cd build
fulcrum@electrum-server:~/Fulcrum/build$
```

- use qmake to generate make file:
```sh
fulcrum@electrum-server:~/Fulcrum/build$ qmake ../Fulcrum.pro \
  "CONFIG-=debug" \
  "CONFIG+=release" \
  "LIBS+=-L/tmp/fulcrum-build/lib/rocksdb -lrocksdb" \
  "LIBS+=-lz -lbz2" \
  "LIBS+=-L/tmp/fulcrum-build/lib/jemalloc -ljemalloc" \
  "LIBS+=-L/tmp/fulcrum-build/lib/zstd -lzstd" \
  "LIBS+=-L/usr/lib/x86_64-linux-gnu -lgssapi_krb5" \
  "LIBS+=-L/tmp/fulcrum-build/lib/sodium -lsodium" \
  "LIBS+=-L/tmp/fulcrum-build/lib/lz4 -llz4" \
  "LIBS+=-L/tmp/fulcrum-build/lib/pgm -lpgm" \
  "LIBS+=-L/tmp/fulcrum-build/lib/snappy -lsnappy" \
  "LIBS+=-L/tmp/fulcrum-build/lib/zmq -lzmq" \
  "INCLUDEPATH+=/usr/include"
```

- make with half of available cores:
```sh
fulcrum@electrum-server:~/Fulcrum/build$ make -j$(echo "$(nproc)/2" | bc)
```

- copy the build binaries to the `~/bin` directory:
  - this step is necessary for every update
  - it should be copied to a separate directory to avoid cleaning build files
```sh
fulcrum@electrum-server:~/Fulcrum/build$ cd
fulcrum@electrum-server:~$ mkdir /home/fulcrum/bin
fulcrum@electrum-server:~$ cp /home/fulcrum/Fulcrum/FulcrumAdmin \
  /home/fulcrum/Fulcrum/build/Fulcrum /home/fulcrum/bin
```

### Fill authorizations for the electrum server via RPC cookie

- log in as the `fulcrum` user if not already:
```sh
fulcrum@electrum-server:/home/user$ cd
fulcrum@electrum-server:~$
```

- create fulcrum and bitcoin data directory:
```sh
fulcrum@electrum-server:~$ mkdir -m 0700 /home/fulcrum/.fulcrum
fulcrum@electrum-server:~$ mkdir -m 0700 /home/fulcrum/.bitcoin
```

- setup bitcoin cookie authentication:
  - replace the RPC user and password that was created for fulcrum above
```sh
fulcrum@electrum-server:~$ echo "
<rpc-user>:<rpc-pass>
" | tee /home/fulcrum/.bitcoin/.cookie
```

- lower cookie permission to only be readable writable by the fulcrum user:
```sh
fulcrum@electrum-server:~$ chmod 0600 /home/fulcrum/.bitcoin/.cookie
```

### Electrum server configuration

- create fulcrum configuration file: ([example](https://github.com/cculianu/Fulcrum/blob/master/doc/fulcrum-example-config.conf)):
  - fulcrum database may corrupt if the process is killed ungracefully, it can
    happen if the if the process is consuming almost all memory of the system
    and Linux OOM (Out-of-Memory) killer drastically kills it. It is important
    to give enough memory so it can be fast but not above 75% of total memory,
    so it is not killed by OOM.
  - `db_mem` caps the amount of memory assigned to the database. After first
    sync, assigning the database memory to `800` is more than enough.
  - `fast-sync` option is only used during the first sync, later it is ignored.     As the name says, it syncs faster by saving some data to cache.
```sh
fulcrum@electrum-server:~$ echo "
## bitcoind settings
bitcoind = 127.0.0.1:8332
rpccookie = /home/fulcrum/.bitcoin/.cookie

## fulcrum settings
datadir = /home/fulcrum/.fulcrum/database
tcp = 0.0.0.0:50001
ts-format = utc

## optimizations
bitcoind_clients = 1
bitcoind_timeout = 60
db_max_open_files = 200
db_mem = $(free -m | grep "^Mem: " | awk '{print $2*5/9}')
fast-sync = $(free -m | grep "^Mem: " | awk '{print $2*1/5}')
max_clients_per_ip = 12

## privacy
peering = false
announce = false
" | tee -a /home/fulcrum/.fulcrum/fulcrum.conf
```

- exit back to `user`:
```sh
fulcrum@electrum-server:~$ exit
user@electrum-server:~$
```

### Configure electrum server systemd service

- make systemd directory on /rw/config:
```sh
user@electrum-server:~$ sudo mkdir -m 0700 /rw/config/systemd
```

- create systemd service for fulcrum:
```sh
user@electrum-server:~$ echo "
[Unit]
Description=Fulcrum
Documentation=https://github.com/cculianu/Fulcrum/blob/master/doc/fulcrum-example-config.conf
Documentation=https://github.com/bitcoin/bitcoin/blob/master/doc/init.md
ConditionPathExists=/home/fulcrum/bin/Fulcrum
ConditionPathExists=/home/fulcrum/.fulcrum/fulcrum.conf
After=qubes-sysinit.service
StartLimitBurst=2
StartLimitIntervalSec=20

[Service]
ExecStart=/home/fulcrum/bin/Fulcrum /home/fulcrum/.fulcrum/fulcrum.conf
OOMScoreAdjust=500
#KillSignal=SIGINT
User=fulcrum
TimeoutStopSec=300
RestartSec=5
Restart=always

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
" | sudo tee /rw/config/systemd/fulcrum.service
```

- lower fulcrum service permissions:
```sh
user@electrum-server:~$ sudo chmod 0600 /rw/config/systemd/fulcrum.service
```

### Misc hardening

- block torbrowser from starting in this qube:
  - if you want to surf, use another VM.
```sh
user@electrum-server:~$ sudo mkdir -p -m 755 /usr/local/etc/torbrowser.d
user@electrum-server:~$ echo "tb_no_start=true" \
| sudo tee -a /usr/local/etc/torbrowser.d/50_user.conf
```

### Configure boot script

- start fulcrum on boot:
```sh
user@electrum-server:~$ echo "
qvm-connect-tcp ::8332
qvm-connect-tcp ::8433

cp -r /rw/config/systemd/* /lib/systemd/system/
systemctl daemon-reload
for service in /rw/config/systemd/*; do
  systemctl restart ${service##*/}
done
" | sudo tee -a /rw/config/rc.local
```

## Finish

Finish setup:
```sh
user@electrum-server:~$ sudo /rw/config/rc.local
```

Watch logs with:
```sh
user@electrum-server:~$ sudo journalctl -fu fulcrum
```

## Make the electrum server reachable via tor

Note: This step is only necessary if you want to expose your electrum server
via tor, it is still possible to connect to the electrum server to a non
networked qube for electrum wallet on the same machine via Qubes RPC, as will
be demonstrated on the `electrum-client` guide.

### Whonix-Gateway AppVM dedicated to electrum server actions:

On `sys-bitcoin`:

- configure the onion service:
```sh
user@sys-bitcoin:~$ echo "
HiddenServiceDir /var/lib/tor/services/fulcrum
HiddenServicePort 50001 <electrum-server-qube-ip>:50001
" | tee -a /usr/local/etc/torrc.d/50_user.conf
```

- reload tor to apply changes to the new configuration
```sh
user@sys-bitcoin:~$ sudo systemctl reload tor@default
```

- make a note of your server hostname to use with a remote Electrum wallet:
```sh
user@sys-bitcoin:~$ sudo cat /var/lib/tor/services/fulcrum/hostname
```

The electrum server is now avaialable on `<onion_hostname>:50001`.

- deny workstation transparent proxy connections
- open connection to the aforementioned socks ports in the firewall
```sh
user@sys-bitcoin:~$ sudo mkdir -p -m 0755 /usr/local/etc/whonix_firewall.d
user@sys-bitcoin:~$ echo "
## deny transparent proxy for security
WORKSTATION_TRANSPARENT_TCP=0
WORKSTATION_TRANSPARENT_DNS=0

## allow daemon exclusive socks
INTERNAL_OPEN_PORTS+=" 9400 9401 "
" | tee -a /usr/local/etc/whonix_firewall.d/40_bitcoin.conf
```

- reload whonix firewall to apply changes:
```sh
user@sys-bitcoin:~$ sudo whonix_firewall
```

### Whonix-Workstation AppVM dedicated to electrum server actions:

On `electrum-server`:

- make a persistent directory for new firewall rules:
```sh
user@electrum-server:~$ sudo mkdir -p -m 0755 /usr/local/etc/whonix_firewall.d
```

- open the electrum server port on the firewall:
```sh
user@electrum-server:~$ echo 'EXTERNAL_OPEN_PORTS+=" 50001 "' \
  | sudo tee -a /usr/local/etc/whonix_firewall.d/50_user.conf
```

- restart the firewall to apply changes:
```sh
user@electrum-server:~$ sudo whonix_firewall
```
