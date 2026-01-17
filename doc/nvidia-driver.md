This article aims to explore and give a practical example of leveraging 
SaltStack to automate [NVIDIA GPU passthrough into Linux HVMs for CUDA applications - Qubes OS forum](https://forum.qubes-os.org/t/nvidia-gpu-passthrough-into-linux-hvms-for-cuda-applications/9515/1). Current iteration of the state have 
grown into a canonical [salt formula](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html), thus the article also serves as a thorough 
documentation to it.

This guide assumes that you're done fiddling with your IOMMU groups and have 
modified grub parameters to allow passthrough.

In addition to that, if you haven't set up salt environment yet, complete step 
1.1 as described in [this guide](https://forum.qubes-os.org/t/qubes-salt-beginners-guide/20126#p-90611-h-11-creating-personal-state-configuration-directories-3) to get ready.

# The basics

This section describes salt to the readers that only have slight familiarity 
with salt.

You probably already know that salt configurations are stored in `/srv/`. 
Here's how it may look:
```
├── user_formulas
│   └── nvidia_driver
│       └── nvidia_driver
│           ├── create.sls
│           ├── full_desktop.sls
│           ├── init.sls
│           ├── nvrun
│           ├── prime.sls
│           ├── revert_desktop.sls
│           └── zero_swap.sls
├── user_pillar
│   ├── custom.sls
│   └── top.sls
└── user_salt
    ├── test.sls
    └── top.sls
```

Let's start with the obvious. `top.sls` inside `user_salt` is a [**top file**](https://docs.saltproject.io/en/latest/ref/states/top.html#the-top-file). It 
describes **high state**, which is really just a combination of salt states. 
`test.sls` is a **state file**. It contains instructions that describe 
requested configuration to the configuration management engine. Engine applies 
these instructions using **state modules**. State module is a piece of code that 
has pretty specific functionality. For example, state module [`pkgrepo`](https://docs.saltproject.io/en/latest/ref/states/all/salt.states.pkgrepo.html#module-salt.states.pkgrepo)
handles repositories of package managers like `apt` and `dnf`.

> One thing to note here is that state module isn't the only kind of module. 
> There are [a lot](https://docs.saltproject.io/en/latest/py-modindex.html) of them, and they can do various things, but here we only need 
> the state kind.

`top.sls` inside `user_pillar` is a **pillar top file**. It is similar to a 
salt top file, but instead of describing which states must be applied to 
what minions, it describes which **pillars** are available to the minions.
Pillar is essentially a form of data storage that might contain configuration 
variables, secrets, or any other data.

People familiar with jinja might be wondering what is the difference between 
storing data in jinja compared to a pillar. The answer is simple - jinja 
must be `include`d or otherwise imported to become available. Pillar data is 
always available no matter what state is being applied, and allows centralized 
declarative control over which minions have access to what data using tops and 
jinja logic in tops and pillars. As with many other salt features, there are 
pillar-related salt calls. For example, you can inspect all data available to 
a minion using `qubesctl --show-output --target $MINION pillar.items` or 
use `qubesctl --show-output --target $MINION pillar.get $ITEM` to get just one 
item.

[**Formula**](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html) is nothing more than a state. The main difference between 
formulas and conventional states is that formulas are often designed to be 
self-sufficient and do somewhat specific set of tasks with minimal configuration required.
Think of them kind of like python modules or vim plugins - just a piece of 
code you can include into your environment. You totally can edit their logic or 
write your own version to solve the same problem. 

`nvidia-driver` formula is stored as a directory. This is an alternative way to 
store state for situations when you want to keep multiple files (including 
other states) nicely organized. When a state directory is referenced, salt 
evaluates `init.sls` state file inside. State files may or may not be included 
from `init.sls` or other state files. This pattern can be used with pillars as well.

Instructions in a state file come as [state declarations](https://docs.saltproject.io/en/latest/topics/tutorials/states_pt1.html#create-an-sls-file). Each state 
declaration invokes a single state module. States declarations behave like 
commands or functions and methods of a programming language. At the same time, 
salt formulas are distinct from conventional programming languages in their 
order of execution. Unless you clearly define the order using arguments like 
`require`, `require_in`, and `order`, you should not expect states to execute 
in any particular sequence.

In addition to state declarations in yaml, you will see jinja instructions. [Jinja](https://palletsprojects.com/projects/jinja/) 
is a templating engine. What it means is that it helps you to generalize your 
state files by adding variables, conditions and other cool features. You can 
easily recognize jinja by fancy brackets: `{{ }}`, `{% %}`, `{# #}`.

Jinja behavior differs depending on what delimiter is used. Code in double 
brackets (called expression) tells the parser to "print" the resulting value 
into state file before the show starts. Statements (`{% %}`) do logic. 
`{# #}` is a comment.

Syntax itself is very similar to python, see [jinja documentation](https://jinja.palletsprojects.com/en/stable/templates/) and [understanding jinja (salt documentation)](https://docs.saltproject.io/en/latest/topics/jinja/index.html).

# The Solution

This section documents current implementation of `nvidia_driver` formula, its 
configuration, and use.

At the moment of writing (2026-01), the formula is tested on debian-13-xfce 
and fedora-42-xfce templates.

It is expected to work on minimal templates as well, provided that the user 
configures such a template to work with distribution-provided (as opposed to 
QubesOS-provided) kernel (see [minimal template documentation](https://doc.qubes-os.org/en/latest/user/templates/minimal-templates.html#distro-specific-notes)).

It is also expected to work on debian-12 and fedora-41 with little to no issues.

Distributions other than debian and fedora are not expected to work and 
their configuration is prevented by jinja.

## Overview

```
.
├── nvidia_driver
│   └── nvidia_driver
│       ├── create.sls          # Create template
│       ├── init.sls            # Install drivers
│       ├── nvrun               # Run a program in prime environment
│       ├── prime.sls           # Install prime environment script (nvrun)
│       └── zero_swap.sls       # Set swapiness to 0
└── pillar.example              # All available configuration parameters
```

I leave the installation overwiev from the previous version here just in case it
will be useful for somebody:

| #   | fedora 42                                                                                | debian 12                        | minimal debian 13                |
| :-: | :--------------------------------------------------------------------------------------- | :------------------------------- | :------------------------------- |
| 0.  | -                                                                                        | -                                | Prepare hvm template             |
| 1.  | Prepare standalone                                                                       | Prepare standalone               | Prepare standalone               |
| 2.  | Enable rpmfusion repositories                                                            | Add repository components        | Add repository components        |
| 3.  | **optional** : Grow `/tmp/` if 1G isn't enough for the driver build process              | -                                | -                                |
| 4.  | Install drivers & wait for build                                                         | Update, upgrade, install drivers | Update, upgrade, install drivers |
| 5.  | Delete X config                                                                          | -                                | -                                |
| 6.  | **optional** : Disable nouveau, if nvidia driver isn't used after installation.          | -                                | -                                |
| 7.  | **optional** : Install a script for running programs in a prime-accelerated environment  | same                             | same                             |

## `nvidia_driver` (`nvidia_driver/nvidia_driver/init.sls`)

This state configures package manager repositories and installs necessary 
packages. Jinja is used to select configuration based on the distribution. If you want 
similar features in your project - `qubesctl grains.items` lists grains of a 
minion.

Just as in previous versions, fedora installation is problematic - dnf doesn't 
work well with `pkgrepo.managed` and the conflict with `grubby-dummy`
is still present.

[Folded block scalar](https://yaml.org/spec/1.2.2/#65-line-folding) (`>`) is used to improve readability of long values. 
It replaces newlines with whitespaces and trims trailing whitespaces. Be 
careful if you want to use it, it uses indentation to tell when block ends.

`require_in` parameters are used to dynamically add requirement to the 
installation state depending on what repository handling mechanism is used.

Installation state itself includes a lot of jinja to cram three package list 
variants and additional states required by fedora under a single ID.

Jinja is also used to avoid minions and distributions this formula 
isn't designed for.

It doesn't check for specific distribution version - metapackages are used
in hopes that their names won't change - if specific package or older version is 
needed, the following pillar data structure set by user can override the defauls:

```yaml
nvidia_driver:
  packages:
    - package1
    - package2
```

[details="init.sls"]
```yaml
{% if grains['id'] != 'dom0' %}
{% if grains['os'] == 'Fedora' %}
{{ grains['id'] }}-nvidia-driver--prepare:
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
{% endif %}
{% endif %}
```
[/details]

## `nvidia_driver.create` (`nvidia_driver/nvidia_driver/create.sls`)

This state clones and configures a template - potentially to apply the main 
state (`init.sls`) to.

Most of the configuration options are taken from the pillar dictionary. 
Exceptions are :

- `maxmem` - Disables memory balancing, must be set to work in hvm mode with 
    distribution-provided kernel
- `virt_mode` - Must be set to hvm for I/O MMU passthrough to work
- `kernel` - Must be set to none, it makes the qube use the 
    distribution-provided kernel

The pillar dictionary contains sub-dictionary for all configurable states in the 
formula - this state uses `pillar['nvidia-driver']['create']` for its values.

In this version I use - and loop through - a dictionary. Using a list of 
dictionaries would've been a better (and shorter) option. I've left it as an 
artifact of my early tinkering with this formula, and I will eventually remove 
it if it stays unused.

This state uses `qvm.vm` state module, a wrapper around other modules, like 
`prefs`, `features`, [etc](https://github.com/QubesOS/qubes-mgmt-salt-dom0-qvm?tab=readme-ov-file#qvm-vm). Since `qvm.vm` doesn't include `qvm.clone`, I am 
forced to use it separately.

[details="create.sls"]
```yaml
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
```
[/details]

## `nvidia_driver.zero_swap` (`nvidia_driver/nvidia_driver/zero_swap.sls`)

This and following states are auxiliary to the main functionality. `zero_swap` 
specifically sets swappiness to 0, thus requesting the system to use RAM as 
much as possible and only resorting to swap when it gets to the high watermark.

[details="zero_swap.sls"]
```yaml
{# Reduce swappiness to the minimum #}

{% if grains['id'] != 'dom0' %}

{{ grains['id'] }}-nvidia-driver--minimize-swap:
  sysctl.present:
    - name: vm.swappiness
    - value: 0

{% endif %}
```
[/details]

## `nvidia_driver.prime` (`nvidia_driver/nvidia_driver/prime.sls`)

This state installs a simple script that runs the argument you give it in a 
prime-accelerated environment.

[Prime](https://wiki.archlinux.org/title/PRIME) is a technology used to manage hybrid graphics. For example, 
to offload render tasks to a powerful GPU despite it not having a monitor 
connected to it directly. Good real-world example of this is a gaming laptop. 
They generally have built-in displays connected directly to the CPU, but use 
Prime in order to render things like videogames effectively. NVIDIA implementation 
of Prime is called Optimus.

Configuration of Optimus Prime is extremely simple. Everything you need to 
offload rendering tasks to your GPU after installing the drivers is to set two 
environment variables. Here I use a simple script for this, but there are 
open-source projects that do it for you, such as [Bumblebee](https://github.com/Bumblebee-Project/Bumblebee).

[details="prime.sls"]
```yaml
{# Install prime script (nvrun) #}

{{ grains['id'] }}-nvidia-driver--prime:
  file.managed:
    - name: /home/user/.local/bin/nvrun
    - source: salt://nvidia_driver/nvrun
    - user: user
    - group: user
    - mode: 700
    - makedirs: True
```
[/details]

[details="nvrun"]
```bash
#!/usr/bin/env bash

(
  set -o errexit
  set -o errtrace

  export __NV_PRIME_RENDER_OFFLOAD=1
  export __GLX_VENDOR_LIBRARY_NAME=nvidia

  $@
)
```
[/details]

Good way to confirm that prime is working correctly is to execute `glxinfo -B` 
(part of the `mesa-utils`) and check it's output. When ran by itself, it 
returns something like `llvmpipe (LLVM <version> ...)` in `OpenGL 
renderer string`. If your prime setup works correctly, running `nvrun glxinfo 
-B` results in your nvidia card showing up in the aforementioned field.

## Configuration And Use
### Installation

You can follow [the official salt documentation](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html) to install formula in 
an appropriate directory. Be aware of the way salt interprets `file_roots` - 
if you want to make the formula available by adding 
`/srv/user_formulas/nvidia_driver` to `file_roots`, then make sure that 
`/srv/user_formulas/nvidia_driver` contains another `nvidia_driver` directory:

```
/srv/user_formulas/
└── nvidia_driver
    └── nvidia_driver
        ├── create.sls
        ├── init.sls
        ├── nvrun
        ├── prime.sls
        └── zero_swap.sls
```

Otherwise, when salt scans `/srv/user_formulas/nvidia_driver` path for 
`nvidia_driver` state, it will fail to find it because it only sees this:

```
.
├── create.sls
├── init.sls
├── nvrun
├── prime.sls
└── zero_swap.sls
```

Technically, as far as I can tell, this form of installation is completely 
arbitrary - any location defined in `file_roots` should work.

To configure `file_roots` on QubesOS, create a configuration file in 
`/etc/salt/minion.d/`. Since it is desired for it to be parsed last - so it 
overrides other values - calling it something like `zz_user_formulas.conf` is 
a good idea:

```
# /etc/salt/zz_user_formulas.conf
file_roots:
  base:
    - /srv/salt
  user:
    - /srv/user_salt
    - /srv/user_formulas/nvidia_driver

pillar_roots:
  base:
    - /srv/pillar
  user:
    - /srv/user_pillar
```

### Configuration

The formula is designed to avoid configuration if not required. The main use 
case is driver installation itself - thus to install drivers in an already 
existing hvm qube one simply adds the formula to the highstate and applies it:

```yaml
# /srv/salt/top.sls
{# Install driver to debian-13-nv and set swapiness to 0 #}
user:
  debian-13-nv:
  - nvidia_driver
  - nvidia_driver.zero_swap

{# Install driver to fedora-42-nv and install the prime script #}
  fedora-42-nv:
  - nvidia_driver
  - nvidia_driver.prime
```

As already stated in the previous section, this state allows overriding 
installed packages by setting package list in a pillar.

Configuration of `nvidia_driver.create` is more involved. `pillar.example` 
contains an example configuration with instructions. It can be copied as is, 
but most values (except of maybe name, source, and menuitems) are highly 
situational.

All pillar data for this formula is stored in a single dictionary to prevent 
namespace conflicts.

[details="pillar.example"]
```yaml
# vim: sw=2 syntax=yaml:
{# 
  This configuration is required if you are going to use template creation 
  or desktop management states provided by the formula. Driver installation 
  has defaults and only requires configuration if you need to select packages 
  manually.
#}
nvidia-driver:
{% if grains['id'] == 'dom0' %}
  create:
    {# 
      item names can be pretty much anything you want, not just `fedora` and 
      `debian`. It is only used as a list of values to loop through when 
      creating and managing vms in dom0.
    #}
    debian:
      name: 'debian-13-nv'
      source: 'debian-13-xfce'
      label: 'purple'
      vcpus: 4
      memory: 4000
      devices:
        - '01:00.0'
        - '01:00.1'
      menuitems: 
        - 'qubes-run-terminal.desktop'
    fedora:
      name: 'fedora-42-nv'
      source: 'fedora-42-xfce'
      label: 'purple'
      vcpus: 4
      memory: 4000
      devices:
        - '01:00.0'
        - '01:00.1'
      menuitems: 
        - 'qubes-run-terminal.desktop'
  full_desktop:
    - 'fedora-42-nv'
{# DO NOT USE grains['os'] HERE, IT RETURNS dom0's OS! #}
{% elif grains['id'] == 'debian-13-nv' %}
  packages:
    - linux-headers-amd64
    - firmware-misc-nonfree
    - nvidia-driver
    - nvidia-open-kernel-dkms
    - nvidia-cuda-dev
    - nvidia-cuda-toolkit
    {# - mesa-utils #}
    {# - nvidia-xconfig #}
{% elif grains['id'] == 'fedora-42-nv' %}
  packages:
    - akmod-nvidia
    - xorg-x11-drv-nvidia-cuda
    {# - glx-utils #}
{% endif %}
```
[/details]

### Other Examples

Create qube, install driver and prime script, configure swappiness:

Top file:
```
# /srv/user_salt/top.sls
user:
  'dom0':
    - nvidia_driver.create

  grinch:
    - nvidia_driver
    - nvidia_driver.zero_swap
    - nvidia_driver.prime
```

Pillar top:
```
# /srv/user_pillar/top.sls
user:
  dom0:
    - nvd

  grinch:
    - nvd
```

The pillar:
```
# /srv/user_pillar/nvd.sls
nvidia-driver:
{% if grains['id'] == 'dom0' %}
  create:
    screwchristmas:
      name: 'grinch'
      source: 'debian-13-xfce'
      label: 'green'
      vcpus: 48
      memory: 128000
      devices:
        - '01:00.0'
        - '01:00.1'
        - '02:00.0'
        - '02:00.1'
        - '03:00.0'
        - '03:00.1'
        - '04:00.0'
        - '04:00.1'
      menuitems: 
        - 'steal_christmas.desktop'
	    - 'kill_santa.desktop'
{% elif grains['id'] == 'grinch' %}
  packages:
    - linux-headers-amd64
    - firmware-misc-nonfree
    - nvidia-driver
    - nvidia-open-kernel-dkms
    - nvidia-cuda-dev
    - nvidia-cuda-toolkit
    - mesa-utils
{% endif %}
```

## Extras

Testing branch contains incomplete automation of full desktop setup - it 
disables QubesOS gui integration without uninstalling any packages in a 
reversible manner.

It works on debian-13. Fedora-42 fails to do autologin and revert is merely 
semi-automatic for both supported distributions - you need to disable debug 
mode of the qube in dom0 manually.

# Downloads
## Current version

- [github](https://github.com/RandyTheOtter/nvidia-driver/tree/main)
- [codeberg](https://codeberg.org/otter2/nvidia-driver)

Contributions, improvements and fixes are welcome! I call it GPL-3 if you need 
that for some reason.

# See also / References

1. Countless posts on the [QubesOS forum](https://forum.qubes-os.org)
1. [Nvidia Graphics Drivers - Debian Wiki](https://wiki.debian.org/NvidiaGraphicsDrivers)
1. [Howto/NVIDIA - RPM Fusion](https://rpmfusion.org/Howto/NVIDIA?highlight=%28%5CbCategoryHowto%5Cb%29)
1. [Mesa - Debian Wiki](https://wiki.debian.org/Mesa)
1. [Nvidia Optimus - Debian Wiki](https://wiki.debian.org/NVIDIA%20Optimus)
1. [PRIME - Arch Linux Wiki](https://wiki.archlinux.org/title/PRIME)
1. [Minimal Templates - QubesOS Documentation](https://doc.qubes-os.org/en/latest/user/templates/minimal-templates.html)
1. [Salt Module Index](https://docs.saltproject.io/en/latest/py-modindex.html)
1. [Jinja Documentation](https://jinja.palletsprojects.com/en/stable/templates/)
1. [Understanding Jinja (Salt Documentation)](https://docs.saltproject.io/en/latest/topics/jinja/index.html)
1. [Storing Static Data in the Pillar](https://docs.saltproject.io/en/latest/topics/pillar/index.html)
1. [Salt Formulas](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html)
