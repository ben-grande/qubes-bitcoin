/rw/config/rc.local:
  file.managed:
    - source:
      - salt://bitcoin-server/rc.local
    - mode: '0755'
    - replace: True

/rw/config/systemd:
  file.directory:
    - mkdirs: True
    - mode: '0700'
    - force: True

/rw/config/whonix_firewall.d:
  file.directory:
    - mkdirs: True
    - mode: '0700'
    - force: True

/rw/config/torbrowser.d:
  file.directory:
    - mkdirs: True
    - mode: '0700'
    - force: True

/rw/config/systemd/bitcoind.service:
  file.managed:
    - source:
      - salt://bitcoin-server/bitcoind.service
    - mode: '0600'
    - replace: True

/rw/config/whonix_firewall.d/50_user.conf:
  file.managed:
    - source:
      - salt://bitcoin-server/whonix_firewall.d/50_user.conf
    - mode: '0600'
    - replace: False

/rw/config/torbrowser.d/50_user.conf:
  file.managed:
    - source:
      - salt://bitcoin-server/torbrowser.d/50_user.conf
    - mode: '0600'
    - replace: True
