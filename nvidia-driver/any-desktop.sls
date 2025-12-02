{# Get a full desktop on a standalone qube with installed drivers #}

{% if qube is not defined %}
{% set qube = {
  'name':'debian-13-cuda',
} %}
{% endif %}

{% if grains['id'] == 'dom0' %}

desktop--enable-debug:
  qvm.prefs:
    - name: {{ qube['name'] }}
    - debug: True
    - virt_mode: hvm

{% elif grains['id'] != 'dom0' %}

desktop--qubes-gui-agent:
  cmd.run:
    - name: systemctl disable qubes-gui-agent

desktop--set-graphical-target:
  cmd.run:
    - name: systemctl set-default graphical.target
    - requires:
      - cmd: desktop--qubes-gui-agent

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