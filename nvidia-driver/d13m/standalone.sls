{# Deploy a cuda-enabled debian 13 minimal qubee with gui agent #}
{# Since this requires multiple reboots, it is split into chapters #}

{# standalone.sls : prepare the standalone, install nvidia drivers #}
{#
  Create a standalone from the hvm-capable minimal template and install nvidia
  drivers in it.
#}

{% if nvd_d13m is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_d13m %}
{% endif %}

{% if grains['id'] == 'dom0' %}

nvidia-driver--create-standalone:
  qvm.vm:
    - name: {{ nvd_d13m['standalone']['name'] }}
    - present:
      - template: {{ nvd_d13m['template']['name'] }}
      - label: {{ nvd_d13m['standalone']['label'] }}
      - flags:
        - standalone
    - prefs:
      - vcpus: {{ nvd_d13m['standalone']['vcpus'] }}
      - memory: {{ nvd_d13m['standalone']['memory'] }}
      - maxmem: 0
      - pcidevs: {{ nvd_d13m['devices'] }}
      - virt_mode: hvm
      - kernel:
    - features:
      - set:
        - menu-items: qubes-run-terminal.desktop

{% elif grains['id'] == nvd_d13m['standalone']['name'] %}

{# Configure the repository #}
nvidia-driver--enable-repo:
  pkgrepo.managed:
    - name: deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian trixie main contrib non-free non-free-firmware
    - file: /etc/apt/sources.list
    
{# Install driver #}
{#
  replace `nvidia-open-kernel-dkms` with `nvidia-kernel-dkms` to have fully
  proprietary setup. 
#}
nvidia-driver--install:
  cmd.run:
    - name: apt-get update -y && apt-get upgrade -y
    - requires:
      - pkgrepo: nvidia-driver--enable-repo
  pkg.installed:
    - names:
      - linux-headers-amd64
      - firmware-misc-nonfree
      - nvidia-driver
      - nvidia-open-kernel-dkms
      - nvidia-cuda-dev
      - nvidia-cuda-toolkit
      {# - mesa-utils #}
    - requires:
      - cmd: nvidia-driver--install

{% endif %}
