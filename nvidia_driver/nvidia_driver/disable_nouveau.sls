{% if grains['id'] != 'dom0' %}

{{ grains['id'] }}-nvidia-driver--blacklist-nouveau:
  file.append:
    - name: /etc/default/grub
    - text: 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX rd.driver.blacklist=nouveau"'

{{ grains['id'] }}-nvidia-driver--grub-mkconfig:
  cmd.run:
    - name: grub2-mkconfig -o /boot/grub2/grub.cfg
    - require:
      - file: {{ grains['id'] }}-nvidia-driver--blacklist-nouveau

{% endif %}
