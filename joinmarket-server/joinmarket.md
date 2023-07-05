# Joinmarket

## Table of Contents
<!-- vim-markdown-toc GFM -->

* [Dom0 actions](#dom0-actions)
* [Whonix-Workstation TemplateVM](#whonix-workstation-templatevm)
* [Whonix-Gateway AppVM](#whonix-gateway-appvm)
  * [Configure exclusive Socks Ports](#configure-exclusive-socks-ports)
* [Whonix-Workstation AppVM](#whonix-workstation-appvm)
  * [Install joinmarket server](#install-joinmarket-server)
  * [Setup bitcoin RPC on the bitcoind VM](#setup-bitcoin-rpc-on-the-bitcoind-vm)
    * [Generate RPC credentials](#generate-rpc-credentials)
    * [Include credentials to the bitcoin configuration file](#include-credentials-to-the-bitcoin-configuration-file)
    * [Include joinmarket watch-only wallet on the bitcoind VM](#include-joinmarket-watch-only-wallet-on-the-bitcoind-vm)
    * [Restart bitcoind to apply changes](#restart-bitcoind-to-apply-changes)
  * [Install joinmarket client](#install-joinmarket-client)

<!-- vim-markdown-toc -->

## Dom0 actions

- clone Whonix-Workstation TemplateVM and name it `whonix-ws-16-joinmarket`:
```sh
[user@dom0]$ qvm-clone whonix-ws-16 whonix-ws-16-joinmarket
```

- create Whonix-Gateway AppVM and name it `sys-joinmarket`:
```sh
[user@dom0]$ qvm-create sys-joinmarket \
  --template whonix-gw-16 \
  --label purple \
  --prop netvm='' \
  --prop maxmem='700' \
  --prop vcpus='1'
```

- create Whonix-Workstation AppVM and name it `joinmarket-server`:
```sh
[user@dom0]$ qvm-create joinmarket-server \
  --template whonix-ws-16 \
  --label red \
  --prop netvm='sys-joinmarket' \
  --prop maxmem='700' \
  --prop vcpus='1'
```

- create Whonix-Workstation AppVM and name it `joinmarket-client`:
```sh
[user@dom0]$ qvm-create joinmarket-client \
  --template whonix-ws-16 \
  --label black \
  --prop netvm='' \
  --prop maxmem='600' \
  --prop vcpus='1'
```

- allow connection from `joinrmarket-sever` to `bitcoin-server` on port `8332`
- allow connection from `joinrmarket-client` to `joinmarket-server` on port `27183`
```sh
[user@dom0]$ echo "
qubes.ConnectTCP +8332 joinmarket-server @default allow target=bitcoin-server
qubes.ConnectTCP +27183 joinmarket-client @default allow target=joinmarket-server
" | tee -a /etc/qubes/policy.d/80-qwbtc.policy
```

## Whonix-Workstation TemplateVM

On the `whonix-ws-16-joinmarket`:

- update the package cache:
```sh
user@whonix-ws-16-joinmarket:~$ sudo apt update
```

- install dependencies:
```sh
user@whonix-ws-16-joinmarket:~$ sudo apt install \
  git \
  libtool libffi-dev libssl-dev libltdl-dev libsodium-dev \
  python3-dev python3-pip python3-virtualenv python3-setuptools \
  python3-matplotlib \
  python3-scipy \
  libsecp256k1-dev \
  python3-pyside2.qtcore python3-pyside2.qtgui \
  python3-pyside2.qtwidgets python3-pyqt5 zlib1g-dev \
  libjpeg-dev libltdl-dev
```

- create system user:
```sh
user@whonix-ws-16-joinmarket:~$ sudo adduser --system joinmarket
```

- shutdown template:
```sh
user@whonix-ws-16-joinmarket:~$ sudo poweroff
```

## Whonix-Gateway AppVM

On `sys-joinmarket`:

### Configure exclusive Socks Ports

The following configuration is only necessary if you don't those ports configured from
Whonix system.

- allow bitcoin daemon to communicate with standard connections on port `9400`
- allow bitcoin daemon to communicate with onion only connections on port `9401`
```sh
user@sys-bitcoin:~$ echo "
## port for joinmarket onion exclusive connections
## 9400 for onion messaging connections
SocksPort $(qubesdb-read /qubes-ip):9400 IsolateDestAddr IsolateDestPort OnionTrafficOnly
## 9401 for onion payjoin client
SocksPort $(qubesdb-read /qubes-ip):9401 IsolateDestAddr IsolateDestPort OnionTrafficOnly
" | sudo tee /usr/local/etc/torrc.d/40_bitcoin.conf
```

- reload tor to apply changes:
```sh
user@sys-bitcoin:~$ sudo systemctl reload tor
```

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

## Whonix-Workstation AppVM

### Install joinmarket server

On the `joinmarket-server`:

- switch to the user `joinmarket` and change to home directory:
```sh
user@joinmarket-server:~$ sudo -H -u joinmarket bash
joinmarket@joinmarket-server:/home/user$ cd
joinmarket@joinmarket-server:~$
```

- clone the bitcoin git repository:
```sh
joinmarket@joinmarket-server:~$ git clone https://github.com/JoinMarket-Org/joinmarket-clientserver
```

- enter the joinmarket directory and receive the signing keys:
  - you can verify the key fingerprint in the [release notes](https://github.com/JoinMarket-Org/joinmarket-clientserver/releases)
  - alternative: `gpg --recv-keys "2B6F C204 D9BF 332D 062B 461A 1410 01A1 AF77 F20B"`
  - Adam Gibson also showed his key on [this 20190605 YouTube video](https://yewtu.be/watch?v=hwmvZVQ4C4M&t=180s)
```sh
joinmarket@joinmarket-server:~$ cd ~/joinmarket-clientserver
joinmarket@joinmarket-server:~/joinmarket-clientserver$ scurl https://raw.githubusercontent.com/JoinMarket-Org/joinmarket-clientserver/master/pubkeys/AdamGibson.asc | gpg --import -
```

- verify the tag you want to checkout (e.g.: v0.9.8) (expect `Good signature`):
```sh
joinmarket@joinmarket-server:~/joinmarket-clientserver$ git tag -n | tail -1
joinmarket@joinmarket-server:~/joinmarket-clientserver$ git verify-tag v0.9.8
```

- checkout tag:
```sh
joinmarket@joinmarket-server:~/joinmarket-clientserver$ git checkout v0.9.8
```

- copy verified joinmarket repository from `joinmarket-server` to
  `joinmarket-client`:
  - select `joinmarket-client` on the Dom0 popup
```sh
joinmarket@joinmarket-server:~/joinmarket-clientserver$ qvm-copy ~/joinmarket-clientserver
```

- generate the configure script with autogen:
```sh
joinmarket@joinmarket-server:~/joinmarket-clientserver$ virtualenv -p python3 jmvenv
joinmarket@joinmarket-server:~/joinmarket-clientserver$ source jmvenv/bin/activate
(jmvenv) joinmarket@joinmarket-server:~/joinmarket-clientserver$
```

- install the daemon:
  - every joinarket qube requires `jmbase`
  - every joinmarket component is being installed because the qube
    `joinmarket-client` is not networked but requires `jclient` and `jmbitcoin`
  - `joinmarket-server` will use `jmdaemon`
```sh
(jmvenv) user@joinmarket-server:~$ python3 setupall.py --all
```

- return to home directory:
```sh
user@joinmarket-server:~/joinmarket-clientserver$ cd
user@joinmarket-server:~$
```

- use systemd to keep joinmarket daemon running:
```sh
user@joinmarket-server:~$ sudo mkdir -m 0700 /rw/config/systemd
user@joinmarket-server:~$ echo "
[Unit]
Description=JoinMarket daemon

[Service]
WorkingDirectory=/home/joinmarket/joinmarket-clientserver
ExecStart=/bin/sh -c 'jmvenv/bin/python scripts/joinmarketd.py'

User=joinmarket
Type=idle
Restart=on-failure

PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
" | sudo tee /rw/config/systemd/joinmarketd.service
```

- fix systemd file permmissions
```sh
user@joinmarket-server:~$ sudo chmod 0600 /rw/config/systemd/joinmarketd.service
```

### Setup bitcoin RPC on the bitcoind VM

Remote Procedure Call is necessary to interact with the bitcoin daemon from
an external machine.

On `bitcoin-server`:

#### Generate RPC credentials

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

#### Include credentials to the bitcoin configuration file

- include credentials to bitcoin.conf (replace the user and hashed pass):
  - single quotes are used with echo or printf to escape the `$` char from the
    string.
```sh
bitcoin@bitcoin-server:~$ echo '## joinmarket auth
rpcauth=<rpc-user>:<hashed-pass>' \
| tee -a /home/bitcoin/.bitcoin/bitcoin.conf
```

#### Include joinmarket watch-only wallet on the bitcoind VM

A watch-only wallet on the bitcoin server is necessary for Joinmarket.
It is better to use its own separate wallet.

```sh
bitcoin@bitcoin-server:~$ echo '## joinmarket wallet
wallet=joinmarket' | tee -a /home/bitcoin/.bitcoin/bitcoin.conf
```

#### Restart bitcoind to apply changes

Change can only be applied after restart.

- exit from the `bitcoin` user and restart `bitcoind`:
```sh
bitcoin@bitcoin-server:~$ exit
user@bitcoin-server:~$ sudo systemctl restart bitcoind.service
```

### Install joinmarket client

On the `joinmarket-client`:

- move the joinmarket repository from QubesIncoming to the home directory:
```sh
user@joinmarket-client:~$ mv ~/QubesIncoming/joinmarket-server/joinmarket-clientserver ~/
```

- create data directory:
```sh
user@joinmarket-client:~$ mkdir -m 0700 ~/.joinmarket
user@joinmarket-client:~$ mkdir -m 0700 ~/.bitcoin
```

- setup bitcoin cookie authentication:
  - replace the RPC user and password that was created for fulcrum above
```sh
user@joinmarket-client:~$ echo "<rpc-user>:<rpc-pass>" \
| tee /home/user/.bitcoin/.cookie
```

- source the virtual environment and change to the repo `scripts` directory:
```sh
user@joinmarket-client:~$ source ~/joinmarket-clientserver/jmvenv/bin/activate
(jmvenv) user@joinmarket-client:~$ cd ~/joinmarket-clientserver/scripts/
```

- generate configuration file:
```sh
(jmvenv) user@joinmarket-client:~/joinmarket-clientserver/scripts$ python3 wallet-tool.py
```

- deactivate virtual environment, an alias will be set later for ease to use:
```sh
(jmvenv) user@joinmarket-client:~/joinmarket-clientserver/scripts$
user@joinmarket-client:~/joinmarket-clientserver/scripts$
```

- backup original configuration file:
```sh
user@joinmarket-client:~/joinmarket-clientserver/scripts$ cd
user@joinmarket-client:~$ mv ~/.joinmarket/joinmarket.cfg ~/.joinmarket/joinmarket.cfg.orig
```

- create custom joinmarket configuration file:
```sh
user@joinmarket-client:~$ qube_gateway="$(qubesdb-read /qubes-gateway)"
user@joinmarket-client:~$ echo "
[DAEMON]
no_daemon = 0
daemon_port = 27183
daemon_host = 127.0.0.1
use_ssl = false

[BLOCKCHAIN]
blockchain_source = bitcoin-rpc
network = mainnet
rpc_host = 127.0.0.1
rpc_port = 8332
rpc_cookie_file = /home/user/.bitcoin/.cookie
rpc_wallet_file = joinmarket

[MESSAGING:onion]
type = onion
socks5_host = ${qube_gateway}
socks5_port = 9401
## onion service virtual port hardcoded to 80
onion_serving_host = 127.0.0.1
onion_serving_port = 8090
## do not set it, we want ephemeral onions
## it is enforced anyway to DiscardPK via Gateway onion-grater control flag
hidden_service_dir
directory_nodes = 3kxw6lf5vf6y26emzwgibzhrzhmhqiw6ekrek3nqfjjmhwznb2moonad.onion:5222,jmdirjmioywe2s5jad7ts6kgcqg66rj6wujj6q77n6wbdrgocqwexzid.onion:5222,bqlpq6ak24mwvuixixitift4yu42nxchlilrcqwk2ugn45tdclg42qid.onion:5222

[MESSAGING:AgoraAnarplexIRC]
type = irc
channel = joinmarket-pit
socks5 = true
socks5_host = ${qube_gateway}
socks5_port = 9401

## begin torified clearnet
#host = agora.anarplex.net
#port = 14716
#uselssl = true
## end torified clearnet

## begin torified onion
host = vxecvd6lc4giwtasjhgbrr3eop6pzq6i5rveracktioneunalgqlwfad.onion
port = 6667
usessl = false
## end torified onion

[MESSAGING:DarkScienceIRC]
type = irc
channel = joinmarket-pit
socks5 = true
socks5_host = ${qube_gateway}
socks5_port = 9401
usessl = false

## begin torified onion
#host = irc.darkscience.net
#port = 6697
#usessl = true
## end torified onion

## begin torified onion
host = darkirc6tqgpnwd3blln3yfv5ckl47eg7llfxkmtovrv7c7iwohhb6ad.onion
port = 6697
usessl = false
## end torified onion

[MESSAGING:HackintIRC]
type = irc
channel = joinmarket-pit
socks5 = true
socks5_host = ${qube_gateway}
socks5_port = 9401

## begin torified clearnet
#host = irc.hackint.org
#port = 6697
#usessl = true
## end torified clearnet

## begin torified onion
host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
port = 6667
usessl = false
## end torified onion

## server disabled by default
#[MESSAGING:IlitaIRC]
#type = irc
#channel = joinmarket-pit
#socks5 = true
#socks5_host = ${qube_gateway}
#socks5_port = 9401

## begin torified onion
#host = ilitafrzzgxymv6umx2ux7kbz3imyeko6cnqkvy4nisjjj4qpqkrptid.onion
#port = 6667
#usessl = false
## end torified onion

[LOGGING]
console_log_level = INFO
color = true

[TIMEOUT]
maker_timeout_sec = 60
unconfirm_timeout_sec = 180
confirm_timeout_hours = 6

[POLICY]
segwit = true
native = true
merge_algorithm = default
tx_fees = 3
tx_fees_factor = 0.2
absurd_fee_per_kb = 350000
max_sweep_fee_change = 0.8
## The peers already know the details, if they have a chance to broadcast, then
## not all broadcasts will be done by our node. But if no peer broadcasts
## then it will fallack to our configured node.
tx_broadcast = random-peer
minimum_makers = 4
interest_rate = 0.015
bondless_makers_allowange = 0.125
bond_value_exponent = 1.3
## BEGIN ANTI-SNOOPING SETTINGS
taker_utxo_retries = 3
taker_utxo_age = 5
taker_utxo_amtpercent = 20
accept_commitment_broadcasts = 1
commit_file_location = cmdata/commitments.json
commit_list_location = cmdata/commitmentlist
## END ANTI-SNOOPING SETTINGS

[PAYJOIN]
payjoin_version = 1
disable_output_substitution = 0
max_additional_fee_contribution = default
min_fee_rate = 1.1
## BEGIN PAYJOIN CLIENT
onion_socks5_host = ${qube_gateway}
onion_socks5_port = 9400
## END PAYJOIN CLIENT
## BEGIN PAYJOIN SERVER
tor_control_host = 127.0.0.1
tor_control_port = 9051
## onion service virtual port hardcoded to 80
onion_service_host = 127.0.0.1
onion_serving_port = 8080
hidden_service_ssl = false
## END PAYJOIN SERVER

[YIELDGENERATOR]
ordertype = reloffer
cjfee_a = 500
cjfee_r = 0.00002
cjfee_factor = 0.1
txfee_contribution
tcfee_contribution_factor = 0.3
minsize = 100000
size_factor = 0.1
gaplimit = 6

[SNICKER]
## snicker is not ready, enforce it to not start
enabled = false
" | tee ~/.joinmarket/joinmarket.cfg
```

- configure rc.local qrexec connections to start on boot:
```sh
user@joinmarket-client:~$ echo "
qvm-connect-tcp 8332:bitcoin-server:8332
qvm-connect-tcp 27183:joinmarket-server:27183

qube_gateway="$(qubesdb-read /qubes-gateway)"
joinmarket_conf="/home/user/.joinmarket/joinmarket.cfg"
if test -f "${joinmarket_conf}"; then
  sed -i'' "s/socks5_host = .*/socks5_host = ${qube_gateway}" "${joinmarket_conf}"
fi
" | tee -a /rw/config/rc.local
```

- activate connections now:
```sh
user@joinmarket-client:~$ sudo /rw/config/rc.local
```

- set joinmarket virtualenvironment more easily:
```sh
user@joinmarket-client:~$ echo '
alias jm="source /home/user/joinmarket-clientserver/jmvenv/bin/activate && cd /home/user/joinmarket-clientserver/scripts/"
' | tee -a ~/.bashrc
```

- source bash user configuration file
- run the alias to enter the virtual environment
```sh
user@joinmarket-client:~$ source ~/.bashrc
user@joinmarket-client:~$ jm
(jmvenv) user@joinmarket-client:~/joinmarket-clientserver/scripts$
```

You are now able to run joinmarket by running the alias `jm`.
