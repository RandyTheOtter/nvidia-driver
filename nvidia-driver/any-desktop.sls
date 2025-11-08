{#
  Get a full desktop on a standalone qube with installed drivers.
#}

{% if grains['id'] == 'dom0' %}

desktop--enable-debug:
  qvm.prefs:
    - name: debian-13-cuda
    - debug: True
    - virt_mode: hvm

{% elif grains['id'] != 'dom0' %}

desktop--purge:
  pkg.purged:
    - pkgs:
      - qubes-gui-agent

desktop--set-graphical-target:
  cmd.run:
    - name: systemctl set-default graphical.target
    - requires:
      - pkg: desktop--purge

desktop--enable-autologin:
  file.replace:
    - name: /etc/lightdm/lightdm.conf
    - pattern: "#autologin-user=*\n"
    - repl: "autologin-user=user\n"

desktop--update-x-config:
  cmd.script:
    - source: salt://nvidia-driver/script/update-x-config.sh
  file.managed:
    - source: salt://nvidia-driver/config/xorg.conf
    - name: /etc/X11/xorg.conf

{% endif %}
