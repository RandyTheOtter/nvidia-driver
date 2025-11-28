{# Deploy a cuda-enabled debian 13 minimal qube with gui agent #}
{# Since this requires multiple reboots, it is split into chapters #}

{# template.sls : prepare the template - enable networking, install kernel #}
{#
  This state creates a template suitable for minimal hvm standalones capable
  of QubesOS networking.
#}

{% if nvd_d13m is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_d13m %}
{% endif %}

{% if grains['id'] == 'dom0' %}

nvidia-driver--create-template:
  qvm.clone:
    - name: {{ nvd_d13m['template']['name'] }}
    - source: {{ nvd_d13m['template-orig']['name'] }}

{% elif grains['id'] == nvd_d13m['template']['name'] %}

nvidia-driver--prepare-template:
  pkg.installed:
    - names:
      - qubes-core-agent-networking
      - linux-image-amd64
      - linux-headers-amd64
      - grub2
      - qubes-kernel-vm-support
  cmd.run:
    - name: grub-install /dev/xvda
    - requires:
      - pkg: nvidia-driver--prepare-template

{% endif %}
