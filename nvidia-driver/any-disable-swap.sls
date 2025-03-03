{# Disable swap completely #}
{# WTF why this doesn't work lol #}

{% if grains['id'] != 'dom0' %}

nvidia-driver--disable-swap:
  file.comment:
    - name: /etc/fstab
    - regex: ^.*swap.*
    - char: '#'
  cmd.run:
    - names:
      - systemctl mask dev-xvdc1.swap
      - systemctl mask xvdc1.swap
    - creates:
      - /etc/systemd/system/dev/xvdc1.swap
      - /etc/systemd/system/xvdc1.swap
  
{% endif %}
