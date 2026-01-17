{# Install prime script (nvrun) #}

{{ grains['id'] }}-nvidia-driver--prime:
  file.managed:
    - name: /home/user/.local/bin/nvrun
    - source: salt://nvidia_driver/nvrun
    - user: user
    - group: user
    - mode: 700
    - makedirs: True
