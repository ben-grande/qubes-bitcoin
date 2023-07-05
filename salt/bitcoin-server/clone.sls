include:
  - qvm.template-whonix-ws

precursor:
  qvm.template_installed:
    - name: whonix-ws-{{ whonix.whonix_version }}

qvm-clone-id:
  qvm-clone:
    - name: whonix-ws-{{ whonix.whonix_version }}-bitcoin-server
    - source: whonix-ws-{{ whonix.whonix_version }}
