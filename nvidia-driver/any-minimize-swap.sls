{# Recude swappiness to the minimum #}

{% if grains['id'] != 'dom0' %}

nvidia-driver--minimize-swap:
  sysctl.present:
    - name: vm.swappiness
    - value: 0

{% endif %}
