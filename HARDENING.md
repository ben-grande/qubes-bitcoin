# Hardening

The hardening steps are compiled on a separate file because it may break some
functionalities.

The scope of this guide is hardening related to the specific purpose of the
project Qubes-Whonix-Bitcoin, anything else is not. Consult upstream.

## Harden Whonix-Gateway against proxy leaks

Transparent proxy has a huge history of proxy leaks, it also does not easily
enforce stream isolation as all workstation traffic is routed through a single
port.

- deny workstation transparent proxy connections:
```sh
$ sudo mkdir -p -m 0755 /usr/local/etc/whonix_firewall.d
$ echo "
## deny transparent proxy for security
WORKSTATION_TRANSPARENT_TCP=0
WORKSTATION_TRANSPARENT_DNS=0
" | tee -a /usr/local/etc/whonix_firewall.d/40_bitcoin.conf
```

- reload whonix firewall to apply changes:
```sh
sudo whonix_firewall
```

## Harden Whonix-Workstation Bitcoin Core RPC against dangerous RPC calls

The following configuration options should be added to `bitcoin.conf`.

By default, all RPC users can call every RPC command, this is dangerous.

### Debugging RPC calls

The disadvantage is that you need to request to the developers of programs
connecting to your RPC interface to provide a full list of required RPC calls.
The other option is trying out by yourself, watching the logs and see what is
required, but this is prone to mistakes as not all commands are called on the
same timeframe.

It may break functionalities by deniying certain calls to applications that
interact with bitcoind, to debug RPC calls, whatch bitcoind logs and use the
following option on your `bitcoin.conf`:
```
debug=rpc
```

### Default RPC whitelist behavior

If you wish to enforce denying every RPC call for all users unless specified
otherwise (default bitcoin daemon behavior is to deny every call if
`rpcwhitelist` option is set to at least once):
```
rpcwhitelistdefault=0
```

The problem with the above option is that it also denies every call from the
`__cookie__` user, which is your local bitcoind user, therefore all RPC
commands will be denied. To overcome this problem, there are three options:
1. allow all RPC calls to all users unless specified otherwise:
```
rpcwhitelistdefault=1
```
2. allow all commands to the `__cookie__` user:
2.1. get all available RPC methods:
```sh
bitcoin-cli help | sed '/^$/d;/==/d;s/ .*$//' | tr "\n" ","
```
2.2. add all rpc methods feteched above to the `__cookie__` user:
```
rpcwhitelist=__cookie__:<all_rpc_methods_from_above>
```
3. specify only certain methods to the `__cookie__` user following the same
   syntax from above for `rpcauth`. It does not contribute to security, because
   if the attacker already has access to your bitcoid daemon qube, they can
   modify the daemon options as they wish.

The problem with options `2` and `3` is that they are prone to missing a method
that is included in later Bitcoin Core releases. The disadvantage with the
option `1` is that all other users that don't have a whitelist specified for
them will be allowed all rules.

### Known requested RPC calls

The following options refer to bitcoind `rpcwhitelist` configuration.

#### Fulcrum known RPC calls

- `estimatesmartfee`
- `getblock`
- `getblockchaininfo`
- `getblockhash`
- `getnetworkinfo`
- `getrawmempool`
- `getrawtransaction`
- `getzmqnotifications`
- `help`
- `sendrawtransaction`
- `uptime`

```sh
rpcwhitelist=<fulcrum_user>:estimatesmartfee,getblock,getblockchaininfo,getblockhash,getnetworkinfo,getrawmempool,getrawtransaction,getzmqnotifications,help,sendrawtransaction,uptime
```
