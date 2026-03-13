{# 
  Get a full desktop on a qube
  WARN: This state doesn't work with all supported systems: autologin doesn't 
  work with fedora. Debian works.
#}

{% if grains['id'] == 'dom0' %}
{% for qube in pillar['nvidia-driver']['full_desktop'] %}

{# TODO: make it add to already existing kernel options #}
{{ qube }}--enable-debug:
  qvm.vm:
    - name: {{ qube }}
  {% if grains['os'] == 'Fedora' %}
    - prefs:
      - virt_mode: hvm
      - memory: 1000
      - kernelopts: "systemd.unit=graphical.target"
    - features:
      - enable:
        - gui-emulated
        - no-nomodeset
    - service:
      - enable:
        - lightdm
  {% elif grains['os'] == 'Debian' %}
    - prefs:
      - virt_mode: hvm
      - memory: 1000
      - kernelopts: "systemd.unit=graphical.target"
    - features:
      - enable:
        - gui-emulated
    - service:
      - enable:
        - lightdm
  {% endif %}

{% endfor %}
{% elif grains['id'] != 'dom0' %}
{{ grains['id'] }}-desktop--enable-autologin:
  file.replace:
    - name: /etc/lightdm/lightdm.conf
    - pattern: "#autologin-user=*\n"
    - repl: "autologin-user=user\n"
{% endif %}
