# qwbtc

**qwbtc** stands for Qubes-Whonix-Bitcoin.

This work is unfinished, do not use it unless you are a developer.

## Table of Contents
<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Disclaimer](#disclaimer)
* [History](#history)
* [Features](#features)
* [Why Qubes-Whonix](#why-qubes-whonix)
* [Disadvantages](#disadvantages)
* [Connections](#connections)
  * [Types](#types)
  * [Protocols](#protocols)
  * [Diagram](#diagram)
  * [Tor Stream Isolation](#tor-stream-isolation)
    * [Disable Transparent Proxy](#disable-transparent-proxy)
    * [Options on by default (no need to worry about adding them):](#options-on-by-default-no-need-to-worry-about-adding-them)
    * [Useful options:](#useful-options)
    * [Connect only to onion services:](#connect-only-to-onion-services)
    * [Other flags are not relevant for this setup:](#other-flags-are-not-relevant-for-this-setup)
    * [Recommended Socks Isolation Flags](#recommended-socks-isolation-flags)
* [How to read the guide?](#how-to-read-the-guide)
* [FAQ](#faq)
* [Suport](#suport)

<!-- vim-markdown-toc -->

## Description

Qubes-Whonix-Bitcoin aims to provide the most software compartimentalized
interaction a user can have with the Bitcoin network and transactions, from the
process of running a full bitcoin node, electrum server, to also teaching how
to use a non-networked wallet that can sync with the self-hosted server.

Simple overview:
1. Xen domains are created via QubesOS interface
2. Each domain runs its specific daemon/service/program
3. Connections between domains are established via [Qrexec](https://www.qubes-os.org/doc/qrexec/)
4. External Connections are made via Whonix-Workstation > Whonix-Gateway

Compatibility:
- Qubes R4.2
- Qrexec policy format R5.0 according to [multifile-policy.markdown](https://github.com/QubesOS/qubes-core-qrexec/blob/master/doc/multifile-policy.markdown)
- Whonix 16
- Bitcoin v0.23.0
- Fulcrum v1.8.1
- Electrum v4.3.2
- Joinmarket v0.9.8

## Disclaimer

We are neither cryptographers nor security experts. Don't trust us, verify the
information we provide with other sources. We are not resposible for any
liability during the use of this project, read the license.

## History

[Qubenix guide](https://github.com/qubenix/qubes-whonix-bitcoin) stopped
supporting it, therefore needing updates to the commands, qrexec policies,
software versions, deamons configuration files.

A lot of the work is common to Qubenix guide, which was the most used source
to make this guide work.

Some improvements made:
- the hostname was set to the qubes name instead of plain `host`
  - this is set by default for Whonix VMs but makes it harder to follow guides
    dealing with multiple VMs
- update qrexec policy format and use a separate policy file
- distinctive qubes names
  - `bitcoind` becomes `bitcoin-server`, easier to notice than a simple 'd'

## Features

- separate qrexec package policy file
- only qubes daemons that will be listening on onion services are networked
- qubes daemons without need of onion service can be set to not networked
  - updates need to be applied by qvm-copy from another trusted vm
- wallets are not networked but have access to their respective daemon
  server port

## Why Qubes-Whonix

QubesOS was chosen because it is a reasonably secure operating system, the
guest operating system Whonix will run unpriviliged, managed by a privileged
domain (AdminVM) non-networked called Domain-0, or dom0 in Qubes parlance.

Whonix of machine separations enforces all traffic from the Whonix-Workstation,
where it hosts the user facing applications such as bitcoind, to pass through
the Whonix-Gateway, where tor resides, and be sent to the Tor network. This
method is called Isolation Proxy and avoids network leaks incoming from the
Whonix-Workstation. Therefore, all traffic incoming from bitcoind will be
forcefully routed through tor without the possibility of network leak.

## Disadvantages

In order to establish a setup or one application per app qube, we sacrifice
computer resources (memory, processing etc.) order to provide more security.

Another topic that may concern some people is exposing the server on plainnet.
This guide does not address this topic, instead it relies on onion services to
optionally expose the server to Tor's network.

## Connections

### Types

Internal connections from clients/wallets are made via Qrexec
- policy: /etc/qubes/policy.d/80-qwbtc.policy

External connections from servers/daemons are made via Whonix-Gateway
- Whonix-Gateway onion service targeting the Whonix-Workstation daemon
- Whonix-Workstation allow daemon port on the firewall for onion service

### Protocols

Bitcoin P2P
- port: 8333
- port: 8334 (onion)
- network: external (onion)
Bitcoin RPC
- port: 8332
- network: internal (127.0.0.1)
Bitcoin ZMQ
- port: 8433
- network: internal (127.0.0.1)
Electrum Server
- port 50001
- network: internal (127.0.0.1, comm to qube electrum wallet)
JoinMarket
- port: 27183
- network: internal (127.0.0.1, comm to qube joinrmarket wallet)
- network: external (onion)

### Diagram

How to read the diagram? Understand the symbols definition:
```text
/----\    /**************\
|qube| -> *remote clients*
\----/    \**************/
  |
  |    /++++++\    /---------\
  \--> +qrexec+ -> |cold qube|
       \++++++/    \---------/
```

```text
/----------------------------------------------------------------\
|                                                                |
| /--------------\    /-----------\    /*******\                 |
| |bitcoin-server| -> |sys-bitcoin| -> *Bitcoin*                 |
| |bitcoind:8333 |    | tor (hs)  |    *  P2P  *                 |
| \--------------/    \-----------/    \*******/                 |
|   |      |                ^   |                                |
| /++++\  /++++\            |   |                                |
| +RPC +  +ZMQ +            |   |                                |
| +8332+  +8433+            |   |                                |
| \++++/  \++++/            |   |                                |
|  |       |                |   |                                |
|  |    /---------------\   |   |    /***************\           |
|  |--> |electrum-server| --/   \--> *Remote Electrum*           |
|  |    | server:50001  |            *    wallets    *           |
|  |    \---------------/            \***************/           |
|  |        |                                                    |
|  |        |    /+++++\    /---------------\                    |
|  |        \--> + ELS + -> |electrum-client|                    |
|  |             +50001+    |    wallet     |                    |
|  |             \+++++/    \---------------/                    |
|  |                                                             |
|  |    /-----------------\    /--------------\    /***********\ |
|  \--> |joinmarket-server| -> |sys-joinmarket| -> * Messaging * |
|       |  server:27183   |    |     tor      |    * servers   * |
|       \-----------------/    \--------------/    \***********/ |
|           |                                                    |
|           |    /+++++\    /-----------------\                  |
|           \--> + JMS + -> |joinmarket-client|                  |
|                +27183+    |    wallet       |                  |
|                \+++++/    \-----------------/                  |
|                                                                |
\----------------------------------------------------------------/
```

### Tor Stream Isolation

These are isolation flags that can be used with tor's SocksPort.

Evaluation considers a Workstation that wants to use its own SocksPort with
defined isolation flags, where the Workstation has one main application
requesting connections (bitcoind, fulcrum, joinmarket).

#### Disable Transparent Proxy

The `TransPort` and `DNSPort` is only used for applications to be transparently
routed through tor without the need to configure SocksPort for the program.
This method was implemented on Whonix for usability, not for security or
privacy, as many users would have problems connecting their application if not
transparently routed. Transport and DNSPort uses a single port which can lead
to identity correlation.

Fortunately all applications that we will be using on this project accept socks
proxy, so we will be configuring the SocksPort per application and thus making
transparent proxy unused, so best to deactivate it on the Whonix-Gateway of
the bitcoin services (which if you followed the guide, will be a separate
gateway to not break or correlate with other activities.

On the Whonix-Gateway AppVM for bitcoin activities, we will be using the
following settings for the Whonix Firewall:
```sh
WORKSTATION_TRANSPARENT_TCP=0
WORKSTATION_TRANSPARENT_DNS=0
```

#### Options on by default (no need to worry about adding them):

- **IsolateClientAddr**
  - different Workstations get different streams, relevant
  - very relevant to isolate streams of our different Workstations actitivities
- **IsolateSOCKSAuth**
  - different socks authentications get different streams
  - bitcoind enforces this with `proxyrandomize=1`, which is the default

#### Useful options:

- **IsolateDestAddr**
  - different hosts requested will get different streams
  - very much useful
- **IsolateDestPort**
  - different ports requested will get different streams
  - my view is that this option has minimum efficacy alone, it should be used
    with IsolateDestAddr. The low efficacy alone argument is:
    - upon redirection of the same site to a different port, the site can
      still track you by other means
    - normally the client will request different remote ports when using a
      different protocol (http: 80, https:443, irc: 6667 etc), but for this
      project, bitcoind for example, will always use the P2P network on mainly
      on port 8333, also electrum server peering is disabled, and we are using
      our own electrum server to connect to our wallet, not random servers
  - not so useful but included as it won't cause the delays as there is not
    much requests made to different ports

#### Connect only to onion services:

**OnionTrafficOnly**
- Equivalent to **NonDNSRequest**, **NoIPv4Traffic**, **NoIPv6Traffic**
  - useful for keeping the traffic E2EE and authenticated via onion
  - makes sense is using a select port for onions only, thus makes sense if
    running bitcoind with the option `onlynet=onion` as a safeguard. The
    electrum server if networked is not reaching onions, so doesn't make sense
    for this one, but for joimarket server it is relevant if enforcing onion
    only messaging system.

#### Other flags are not relevant for this setup:

Other isolation flags such as:
- **IsolateClientProtocol**, don't share circuits with streams using a
  different protocol, such as SOCKS 4, SOCKS 5, HTTPTunnelPort, DNSPort etc

Do not apply because:
- as we are using one application per Workstation and the application has its
  own configured socks port, it will use its own socks port, thus the stream
  isolation is enforced per client, then per stream port used

If you find any non listed isolation flag that might be relevant, please let us
know.

#### Recommended Socks Isolation Flags

Excluding default options as they are applied by default, only mentioning
relevant options:
1. `SocksPort host:port IsolateClientAddr IsolateClientPort`
2. `SocksPort host:port IsolateClientAddr IsolateClientPort OnionTrafficOnly`
- bitcoind should use option 2 in combination with bitcoin.conf `onlynet=onion`
- electrum servers peering is disabled, neither applies
- joinmarket server should use option 2 in combination with only onion
  messaging servers configured
- option 1 is fallback if OnionTrafficOnly causes problems in case of DDoS
  attacks on the tor network and onions become unreliable for an extended
  period, but keep in mind that you are lowering your privacy by doing so

Whonix currently implements `IsolateClientAddr IsolateClientPort` on the
Gateway ports range `9180` to `9189`, use it in your favor by [opening their
respective port on the Whonix-Gateway firewall](https://www.whonix.org/wiki/Whonix-Gateway_Firewall#For_Connections_Originating_from_Whonix-Workstation_%E2%84%A2)

Whonix does not currently implement any default configuration using
`OnionTrafficOnly`, but when it does, it is recommended to use it.

If you wish to add non default isolation flags, refer to the [Whonix Wiki](https://www.whonix.org/wiki/Tor#Additional_SocksPorts).

## How to read the guide?

Pay attention, it takes time to do everything and should be done carefully.

Don't trust me, do your own research first, verify the source code of the
project, inspect what you can.

This guide can become outdated in case of future breaking changes to the
packages being installed, package name version growing etc, always consult
the upstream project for instructions.

Whonix purposefully sets the hostname to `host`, and that makes it more
difficult to follow the guide without indication of in which qube the command
should be run, of course you can check the headers, but on the prompt it is
easier to notice.

Because of this, we set our shell prompt to include the correct hostname,so you
don't get lost after running a bunch o commands, you will still be able to
locate yourself more easily.

When relevant, the commands have some comments explaining why their options,
approach was chosen instead of the default. The text is to be read, not to be
overlooked.

## FAQ

**I am using a remote Bitcoind/Electrum/Joinmarket Server, how can I connect to the Wallet/Client qube?**
1. Allow remote connections on the server
  - Bitcoind: opening the JSON-RPC to hosts outside of your local trusted
    network is not recommendd, connections are not encrypted, password is
    transmitted in plaintext, unless configured to use an encrypted tunnel such
    as reverse SSH or a local VPN hosted by you. For bitcoind, allow remote
    RPC connections via option `rpcallowip`.
  - Electrum Server: remote connections depends on the implementation,
    some Electrum servers support TLS over TCP, use it if available.
2. Create listening qube
  - Lower CPU and RAM, it just forwards traffic
  - Name it `bitcoin-server`
  - The examples will use Bitcoin RPC default port `8332` for simplicity,
    but you can substitue when necessary for other services, such as the
    Electrum Server default port `50002`.
  - Change `<rpc-ip>` and `<rpc-onion>` according to your needs.
  - Test the remote host is reacheable: `curl <rpc-ip>:8332`.
  - Remote is on LAN
    - Create AppVM from desired TemplateVM except Whonix and run from inside
      of `bitcoind-server`: `sudo nc -l <rpc-ip> 8332 -c "nc 127.0.0.1 8332"`
  - Remote is onion address
    - Create Whonix-Workstation AppVM and run from inside of `bitcoin-server`:
      `sudo nc -l <rpc-onion> 8332 -c "nc 127.0.0.1 8332"`
  - Test the remote host was binded to localhost: `curl 127.0.0.1:8332`
  - Add the netcat command line to `bitcoin-server` `/rw/config/rc.local` file
3. Create Qrexec policy to allow connections to the listening qube:
  - Define the qube that will use the listening address, let's say it is named
    `electrum-client`
  - Add this line to Dom0 `/etc/qube/policy.d/30-user.policy`: `qubes.ConnectTCP +8332 electrum-client @default allow target=bitcoin-server`
  - Now from the `electrum-client` qube, bind `bitcoin-server` qube port 8332
    to 127.0.0.1:8332, for this run `qvm-connect-tcp ::8332`
  - Test the connection was established correctly by running from inside of the
    `electrum-client`: `curl 127.0.0.1:8332`


## Suport

If you like this guide, you can support by:
- contributing:
  - correcting typos
  - design improvements
  - reporting security risks
- donating to this address TODO
- paid support is also possible, only bitcoin accepted, price to be negotiated
  per request.
