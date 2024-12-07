{% if nvd_f41 is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_f41 %}
{% endif %}

{% if grains['id'] == nvd_f41['standalone']['name'] %}

nvidia-driver.disable-nouveau--blacklist-nouveau:
  file.append:
    - name: {{ nvd_f41['paths']['grub_conf'] }}
    - text: 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX rd.driver.blacklist=nouveau"'

nvidia-driver.disable-nouveau--grub-mkconfig:
  cmd.run:
    - name: grub2-mkconfig -o {{ nvd_f41['paths']['grub_out'] }}
    - require:
      - file: nvidia-driver.disable-nouveau--blacklist-nouveau

{% endif %}
