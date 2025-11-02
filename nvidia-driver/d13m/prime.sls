{# Deploy a cuda-enabled debian 13 minimal qube with gui agent #}
{# Since this requires multiple reboots, it is split into chapters #}

{# prime.sls : install prime script #}

{% if nvd_d13m is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_d13m %}
{% endif %}

nvidia-driver--prime:
  file.managed:
    - name: /home/user/.local/bin/nvrun
    - source: {{ nvd_d13m['paths']['nvrun'] }}
    - user: user
    - group: user
    - mode: 700
    - makedirs: True
