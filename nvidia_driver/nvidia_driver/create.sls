{% if grains['id'] == 'dom0' %}
{% for qube in pillar['nvidia-driver']['create'] %}

{{ pillar['nvidia-driver']['create'][qube]['name'] }}-nvidia-driver--create:
  qvm.clone:
    - name: {{ pillar['nvidia-driver']['create'][qube]['name'] }}
    - source: {{ pillar['nvidia-driver']['create'][qube]['source'] }}

{{ pillar['nvidia-driver']['create'][qube]['name'] }}-nvidia-driver--manage:
  qvm.vm:
    - name: {{ pillar['nvidia-driver']['create'][qube]['name'] }}
    - prefs:
      - label: {{ pillar['nvidia-driver']['create'][qube]['label'] }}
      - vcpus: {{ pillar['nvidia-driver']['create'][qube]['vcpus'] }}
      - memory: {{ pillar['nvidia-driver']['create'][qube]['memory'] }}
      - maxmem: 0
      - pcidevs: {{ pillar['nvidia-driver']['create'][qube]['devices'] }}
      - virt_mode: hvm
      - kernel:
    - features:
      - set:
        - menu-items: {{ ' '.join(pillar['nvidia-driver']['create'][qube]['menuitems']) }}
    - require: 
      - qvm: {{ pillar['nvidia-driver']['create'][qube]['name'] }}-nvidia-driver--create

{% endfor %}
{% endif %}
