{# 
  This salt formula installs nvidia dGPU drivers on a qube.
  
  For configuration example see pillar.example.

  If you want multiple VMs to operate same devices, use `--max-concurrency 1` 
  when executing `qubesctl` - that way the state will be applied sequentially 
  and vms won't "fight" for the same device.
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
{% endif %}
{% endif %}

{% if grains['os'] == 'Debian' or grains['os'] == 'Fedora' %}
{{ grains['id'] }}-nvidia-driver--install:
  pkg.installed:
{% if pillar['nvidia-driver']['packages'] is defined %}
    - names: {{ pillar['nvidia-driver']['packages'] }}
{% else %}
{% if grains['os'] == 'Debian' %}
    - names:
      - linux-headers-amd64
      - firmware-misc-nonfree
      - nvidia-driver
      - nvidia-open-kernel-dkms
      - nvidia-cuda-dev
      - nvidia-cuda-toolkit
{% elif grains['os'] == 'Fedora' %}
    - names:
      - akmod-nvidia
      - xorg-x11-drv-nvidia-cuda
{% endif %}
{% endif %}
{% if grains['os'] == 'Fedora' %}
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

include:
  - nvidia_driver.disable_nouveau
{% endif %}
{% endif %}
