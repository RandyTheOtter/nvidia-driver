{% if grains['id'] == 'dom0' %}
{# 
  FIXME: this state should be applied by hand, not from top file. 
  Don't use pillars.
#}
{#
  {% for qube in pillar['nvidia-driver']['full_desktop'] %}
  {{ qube }}--disable-debug:
    qvm.prefs:
      - name: {{ qube }}
      - debug: True
  {% endfor %}
#}
{% elif grains['id'] != 'dom0' %}

{{ grains['id'] }}-desktop--qubes-gui-agent:
  cmd.run:
    - name: systemctl enable qubes-gui-agent

{{ grains['id'] }}-desktop--set-target:
  cmd.run:
    - name: systemctl set-default multi-user.target
    - requires:
      - cmd: desktop--qubes-gui-agent

{{ grains['id'] }}-desktop--enable-autologin:
  file.replace:
    - name: /etc/lightdm/lightdm.conf
    - pattern: "autologin-user=user\n"
    - repl: "#autologin-user=*\n"

{% endif %}
