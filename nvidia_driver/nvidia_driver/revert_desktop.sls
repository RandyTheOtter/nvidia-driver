{% if grains['id'] == 'dom0' %}
{# 
  FIXME: this state should be applied by hand, not from top file. 
  Don't use pillars.
#}
{#
  {% for qube in pillar['nvidia-driver']['full_desktop'] %}
  {{ qube }}--disable-debug:
    qvm.vm:
      - name: {{ qube }}
      {% if qube['os'] == 'Fedora' %}
      - prefs:
        - virt_mode: default
        - kernelopts: default
      - features:
        - disable:
          - gui-emulated
      - service:
        - disable:
          - lightdm
      {% elif qube['os'] == 'Debian' %}
      - prefs:
        - virt_mode: default
        - kernelopts: default
      - features:
        - disable:
          - gui-emulated
          - no-nomodeset
      - service:
        - disable:
          - lightdm
      {% endif %}
  {% endfor %}
#}
{% elif grains['id'] != 'dom0' %}
{{ grains['id'] }}-desktop--disable-autologin:
  file.replace:
    - name: /etc/lightdm/lightdm.conf
    - pattern: "autologin-user=user\n"
    - repl: "#autologin-user=*\n"
{% endif %}
