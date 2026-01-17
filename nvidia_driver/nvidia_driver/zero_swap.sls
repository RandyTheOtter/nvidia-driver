{# Reduce swappiness to the minimum #}

{% if grains['id'] != 'dom0' %}

{{ grains['id'] }}-nvidia-driver--minimize-swap:
  sysctl.present:
    - name: vm.swappiness
    - value: 0

{% endif %}
