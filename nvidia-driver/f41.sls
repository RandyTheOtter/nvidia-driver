{% if nvd_f41 is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_f41 %}
{% endif %}

{% if grains['id'] == 'dom0' %}

nvidia-driver--create-qube:
  qvm.vm:
    - name: {{ nvd_f41['standalone']['name'] }}
    - present:
      - template: {{ nvd_f41['template']['name'] }}
      - label: {{ nvd_f41['standalone']['label'] }}
      - flags:
        - standalone
    - prefs:
      - vcpus: {{ nvd_f41['standalone']['vcpus'] }}
      - memory: {{ nvd_f41['standalone']['memory'] }}
      - maxmem: 0
      - pcidevs: {{ nvd_f41['devices'] }}
      - virt_mode: hvm
      - kernel:
    - features:
      - set:
        - menu-items: qubes-run-terminal.desktop

{% elif grains['id'] == nvd_f41['standalone']['name'] %}

nvidia-driver--enable-repo:
  cmd.run:
    - name: dnf config-manager setopt rpmfusion-{free,nonfree}{,-updates}.enabled=1

nvidia-driver--extend-tmp:
  cmd.run:
    - name: mount -o remount,size=2G /tmp/

nvidia-driver--remove-grubby-dummy:
  pkg.purged:
    - pkgs:
      - grubby-dummy

nvidia-driver--install:
  pkg.installed:
    - pkgs:
      - akmod-nvidia
      - xorg-x11-drv-nvidia-cuda
      {# - vulkan #}
    - require:
      - cmd: nvidia-driver--enable-repo
      - cmd: nvidia-driver--extend-tmp
  loop.until_no_eval:
    - name: cmd.run
    - expected: 'nvidia'
    - period: 20
    - timeout: 600
    - args:
      - modinfo -F name nvidia
    - require:
      - cmd: nvidia-driver--install

nvidia-driver--remove-conf:
  file.absent:
    - name: {{ nvd_f41['paths']['nvidia_conf'] }}
    - require:
      - loop: nvidia-driver--install

{% endif %}
