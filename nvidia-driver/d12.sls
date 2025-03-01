{# Deploy a cuda-enabled debian 12 qube with gui agent #}

{% if nvd_d12 is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_d12 %}
{% endif %}

{% if grains['id'] == 'dom0' %}

nvidia-driver--create-qube:
  qvm.vm:
    - name: {{ nvd_d12['standalone']['name'] }}
    - present:
      - template: {{ nvd_d12['template']['name'] }}
      - label: {{ nvd_d12['standalone']['label'] }}
      - flags:
        - standalone
    - prefs:
      - vcpus: {{ nvd_d12['standalone']['vcpus'] }}
      - memory: {{ nvd_d12['standalone']['memory'] }}
      - maxmem: 0
      - pcidevs: {{ nvd_d12['devices'] }}
      - virt_mode: hvm
      - kernel:
    - features:
      - set:
        - menu-items: qubes-run-terminal.desktop

{% elif grains['id'] == nvd_d12['standalone']['name'] %}

{# Configure the repository #}
nvidia-driver--enable-repo:
  pkgrepo.managed:
    - name: deb https://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
    - file: /etc/apt/sources.list

{# Install driver #}
nvidia-driver--install:
  cmd.run:
    - name: apt update -y && apt upgrade -y
    - requires:
      - pkgrepo: nvidia-driver--enable-repo
  pkg.installed:
    - names:
      - linux-headers-amd64
      - nvidia-driver
      - firmware-misc-nonfree
      - nvidia-open-kernel-dkms
      - nvidia-cuda-dev
      - nvidia-cuda-toolkit
      {# comment `nvidia-open-kernel-dkms` out to go full proprietary #}
    - requires:
      - cmd: nvidia-driver--install
  loop.until_no_eval:
    - name: cmd.run
    - expected: 'nvidia'
    - period: 20
    - timeout: 600
    - args:
      - modinfo -F name nvidia-current
    - require:
      - pkg: nvidia-driver--install

{% endif %}
