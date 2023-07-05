include:
  - bitcoin-server.clone
  - qvm.template-whonix-gw
  - qvm.template-whonix-ws

precursor_sys-bitcoin:
  qvm.template_installed:
  - name: whonix-gw-{{ whonix.whonix_version }}

template-bitcoin-server:
  qvm-present:
  - name: whonix-ws-{{ whonix.whonix_version }}-bitcoin-server
  - template: whonix-ws-{{ whonix.whonix_version }}
  - label: black

sys-bitcoin:
  qvm.present:
  - name: sys-bitcoin
  - template: whonix-gw-{{ whonix.whonix_version }}
  - label: black

bitcoin-server:
  qvm.present:
  - name: bitcoin-server
  - template: whonix-ws-{{ whonix.whonix_version }}-bitcoin-server
  - label: red

bitcoin-server_prefs:
  qvm.prefs:
  - name: bitcoin-server
  - netvm: sys-bitcoin
  - memory: 400
  - maxmem: 1800
  - vcpus: 2
  - include_in_backups: True

bitcoin-server_features:
  qvm.features:
  - name: bitcoin-server
  - set:
    - menu-items: "Thunar.desktop xfc4-terminal.desktop"

'qvm-volume resize bitcoin-sever:private 800G':
  cmd.run



qvm-present-id:
  qvm.present:
    - name: sys-bitcoin
    - template: whonix-gw-{{ whonix.whonix_version }}
    - label: purple
  qvm.present:
    - name: bitcoin-server
    - template: whonix-ws-{{ whonix.whonix_version }}
    - label: red
    - netvm: sys-bitcoin

qvm-prefs-id:
  qvm-prefs:
    - name: sys-bitcoin
    - memory: 300
    - maxmemory: 400
    - vcpus: 1
    - provides-network: True

qvm-features-id:
  qvm.features:
    - name: sys-bitcoin
    - ipv6: ''
    - disable:
      - service.cups
      - service.cups-browsed
      - service.tinyproxy

sys-bitcoin-present-id:
  qvm-present:
    - name: sys-bitcoin
    - template: whonix-gw-{{ whonix.whonix_version }}
    - label: purple

sys-bitcoin-prefs:
  qvm.prefs:
    - name: sys-bitcoin
    - autostart: false
    - include_in_backups: true

sys-bitcoin-features:
  qvm.features:
    - name: sys-bitcoin

bitcoin-server-present-id:
  qvm.present:
    - name: bitcoin-server
    - template: whonix-ws-{{ whonix.whonix_version }}
    - label: red

bitcoin-server-prefs:
  qvm.prefs:
    - name: bitcoin-server
    - autostart: false
    - include_in_backups: true
    - netvm: sys-bitcoin
