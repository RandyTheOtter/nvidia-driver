{# 
  Get a full desktop on a qube
  WARN: This state doesn't work with all supported systems: autologin doesn't 
  work with fedora. Debian works.
#}

{% if grains['id'] == 'dom0' %}
{% for qube in pillar['nvidia-driver']['full_desktop'] %}

{{ qube }}--enable-debug:
  qvm.prefs:
    - name: {{ qube }}
    - debug: True

{% endfor %}
{% elif grains['id'] != 'dom0' %}

{{ grains['id'] }}-desktop--qubes-gui-agent:
  cmd.run:
    - name: systemctl disable qubes-gui-agent

{{ grains['id'] }}-desktop--set-target:
  cmd.run:
    - name: systemctl set-default graphical.target
    - requires:
      - cmd: desktop--qubes-gui-agent

{{ grains['id'] }}-desktop--enable-autologin:
  file.replace:
    - name: /etc/lightdm/lightdm.conf
    - pattern: "#autologin-user=*\n"
    - repl: "autologin-user=user\n"

{% endif %}
