{# 
  This salt formula sets up a hardware-assisted TemplateVM with installed 
  nvidia dGPU drivers on a Qubes OS system.
  
  For configuration example see pillar.example. You at least need to set 
  PCIe devices you want.

  If you want to configure multiple VMs to operate the same device, use 
  `--max-concurrency 1` when executing `qubesctl` - that way the state will be 
  applied sequentially and vms won't "fight" for the same device.
#}

{% if grains['id'] != 'dom0' %}
{% if grains['os'] == 'Fedora' %}
{{ grains['id'] }}-nvidia-driver--prepare:
{# 
  dnf doesn't recognize changes to /etc/yum.repos.d because of this: https://discussion.fedoraproject.org/t/rpm-repository-configuration-is-not-synced-between-dnf-and-packagekit-gui-package-managers
  Dnf sucks. Remove contents of /etc/dnf/repos.override.d/ , clean all and 
  resync to make it behave, or resort to cmd.run below.
  pkgrepo.managed:
    - names:
      - rpmfusion-free
      - rpmfusion-free-updates
      - rpmfusion-nonfree
      - rpmfusion-nonfree-updates
    - enabled: True 
#}
  cmd.run:
    - name: >
        dnf config-manager setopt 
        rpmfusion-free.enabled=1
        rpmfusion-free-updates.enabled=1
        rpmfusion-nonfree.enabled=1
        rpmfusion-nonfree-updates.enabled=1
    - require_in: 
      - pkg: {{ grains['id'] }}-nvidia-driver--install
  pkg.purged:
    - pkgs:
      - grubby-dummy
    - require_in: 
      - pkg: {{ grains['id'] }}-nvidia-driver--install

{{ grains['id'] }}-nvidia-driver--install:
  pkg.installed:
    - names:
      - akmod-nvidia
      - xorg-x11-drv-nvidia-cuda
      {# - glx-utils #}
    - refresh: True
  loop.until_no_eval:
    - name: cmd.run
    - expected: 'nvidia'
    - period: 20
    - timeout: 600
    - args:
      - modinfo -F name nvidia
    - require:
      - pkg: {{ grains['id'] }}-nvidia-driver--install
  file.absent:
    - name: /usr/share/X11/xorg.conf.d/nvidia.conf
    - require:
      - loop: {{ grains['id'] }}-nvidia-driver--install

{% elif grains['os'] == 'Debian' %}
{{ grains['id'] }}-nvidia-driver--enable-repo:
  pkgrepo.managed:
    - name: >
        deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg]
        https://deb.debian.org/debian {{ grains['oscodename'] }}
        main contrib non-free non-free-firmware
    - file: /etc/apt/sources.list
    - require_in: 
      - pkg: {{ grains['id'] }}-nvidia-driver--install

{{ grains['id'] }}-nvidia-driver--install:
  pkg.installed:
    - names:
      - linux-headers-amd64
      - firmware-misc-nonfree
      - nvidia-driver
      - nvidia-open-kernel-dkms
      - nvidia-cuda-dev
      - nvidia-cuda-toolkit
      {# - mesa-utils #}
      {# - nvidia-xconfig #}
    - refresh: True
{% endif %}
{% endif %}
