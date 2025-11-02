{# any-prime.sls : install prime script #}

{% if script is not defined %}
{% from 'nvidia-driver/default.jinja' import script %}
{% endif %}

nvidia-driver--prime:
  file.managed:
    - name: /home/user/.local/bin/nvrun
    - source: {{ script['nvrun'] }}
    - user: user
    - group: user
    - mode: 700
    - makedirs: True
