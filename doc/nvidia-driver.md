
This little article aims to explore and give a practical example of leveraging SaltStack to achieve the same goal as [NVIDIA GPU passthrough into Linux HVMs for CUDA applications](https://forum.qubes-os.org/t/nvidia-gpu-passthrough-into-linux-hvms-for-cuda-applications/9515/1). Salt is a management engine that simplifies configuration, and QubesOS has its own flavour. Want to see some?

This guide assumes that you're done fiddling with your IOMMU groups and have modified grub parameters to allow passthrough.

In addition to that, if you haven't set up salt environment yet, complete step 1.1 as described in [this guide](https://forum.qubes-os.org/t/qubes-salt-beginners-guide/20126#p-90611-h-11-creating-personal-state-configuration-directories-3) to get ready.

# The basics

Before we even start doing anything, let's discuss the basics. You probably already know that salt configurations are stored in `/srv/user_salt/`. Here's how it may look:
```
.
├── nvidia-driver
│   ├── f41-disable-nouveau.sls
│   ├── f41.sls
│   └── default.jinja
├── test.sls
└── top.sls
```

Let's start with the obvious. `top.sls` is a top file. It describes high state, which is really just a combination of conventional salt formulas. Stray piece of salt configuration can be referred to as `formula`, although I've seen this term used to refer to different things. `test.sls` is a state file. It contains a configuration written in yaml. `nvidia-driver` is also a state, although it is a directory. This is an alternative way to store state for situations when you want to have multiple state (or not only state) files. When a state directory is referenced, salt evaluates `init.sls` state file inside. State files may or may not be included from `init.sls` or other state files.
> Since in this case different formulas are used depending on distribution, it doesn't make much sense to have `init.sls`. In this configuration, you can't just call for `nvidia-driver`, and must specify distribution too: `nvidia-driver.f41`

Yaml configuration consists of states. In this context, state refers to a module - piece of code that most often does a pretty specific thing. In a configuration, states behave like commands or functions and methods of a programming language. At the same time, salt formulas are distinct from conventional programming languages in their order of execution. Unless you clearly define the order using arguments like `require`, `require_in`, and `order`, you should not expect states to execute in any particular sequence.
> One thing to note here is that not all modules *are* state modules. There are [a lot](https://docs.saltproject.io/en/latest/py-modindex.html) of them, and they can do various things, but here we only need the state kind.

In addition to state files, you notice `default.jinja`. [Jinja](https://palletsprojects.com/projects/jinja/) is a templating engine. What it means is that it helps you to generalize your state files by adding variables, conditions and other cool features. You can easily recognize jinja by fancy brackets: `{{ }}`, `{% %}`, `{# #}`. This file in particular stores variable definitions and is used for configuration of the whole state tree (directory `nvidia-folder`).

# Writing salt configuration
## 1. Create a standalone

First, let's write a state to describe how vm shall be created:

```yaml
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
```

Here, I use qubes-specific `qvm.vm` state module (which is a wrapper around other modules, like `prefs`, `features`, [etc](https://github.com/QubesOS/qubes-mgmt-salt-dom0-qvm?tab=readme-ov-file#qvm-vm).). Almost all values and keys here are the same as you can set and get using `qvm-prefs` and `qvm-features`. For nvidia drivers to work, kernel must be provided by the qube - that's why the field is empty. Similarly, to pass GPU we need to set virtualization mode to `hvm` and `maxmem` to 0 (it disables memory balancing).

`nvidia-driver--create-qube` is just a label. As long as you don't cross the syntax writing it, it should be fine. Aside from referencing, plenty of modules can use it to simplify the syntax, and some need it to decide what to do, but you can look it up later if you want.

[details="Preparing minimal qubes"]
As the name implies, minimal qubes don't contain that much of anything. Because of that, preparing a minimal template for creating an accelerated standalone is more involved.

Firstly, minimal template doesn't contain a kernel (it only uses the copy of kernel provided by QubesOS). This means it can't run in HVM mode with "provided by qube" setting.

Secondly, minimal templates lack the qubes networking agent. This results in a standalone created from such a template being unable to access the internet without additional configuration.

To solve these problems, I use a separate state (`template.sls`) to create an hvm-capable minimal template:
```
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
      - pkg: nvidia-driver--enable-network

{% endif %}
```

For more information, see [minimal templates documentation](https://doc.qubes-os.org/en/latest/user/templates/minimal-templates.html)
[/details]

Now, to the jinja statements. Here, they provide values for keys like label, template, name, etc. Some of them are done this way (as opposed to writing a value by hand) because the value is repeated in the state file multiple times, others are to simplify the process of configuration. In this state file jinja variable is imported using the following snippet:
```jinja
{% if nvd_f41 is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_f41 %}
{% endif %}
```
Jinja is very similar in its syntax to python. In this case variable from `default.jinja` gets imported only if it is not declared in the current context. It allows us to both call this formula as is (without any jinja context) and include it in other formulas (potentially with custom definition of `nvd_f41`). Note that you need to specify state directory when importing, and use actual path instead of dot notation.

Upon inspection of `map.jinja`, what we see is:
```python
{% set nvd_f41 = {
  'template':{'name':'fedora-41-xfce'},
  'standalone':{
    'name':'fedora-41-nvidia-cuda',
    'label':'yellow',
    'memory':'4000',
    'vcpus':'4',
  },
  'devices':['01:00.0','01:00.1'],
  'paths':{
    'nvidia_conf':'usr/share/X11/xorg.conf.d/nvidia.conf',
    'grub_conf':'/etc/default/grub',
    'grub_out':'/boot/grub2/grub.cfg',
  },
} %}
```
Here, I declare dictionary `nvd_f41`. It contains sub-dictionaries for template parameters, standalone qube parameters, list of pci devices to pass through, and another dictionary for paths. Since we need to pass all devices in the list to new qube, in the state file I reference whole list.

Jinja behavior differs depending on what delimiter is used. Code in double brackets (called expression) tells the parser to "print" the resulting value into state file before the show starts. Statements (`{% %}`) do logic. `{# #}` is a comment.

## 1.5 Interlude: what's next?

Now, when we have a qube at the ready (you can check it by applying the state), how do we install drivers? I want to discuss what's going on next, because at the moment of writing (November 2025) driver installation processes for fedora 41 and debian 12 are different.

[details="How do I apply a state?"]
To apply a formula, put your state into in your salt environment folder together with jinja file and run
`sudo qubesctl --show-output state.sls <name_of_your_state> saltenv=user`
(substitute `<name_of_your_state>`)

Salt will apply the state to all targets. When not specified, dom0 is the only target. This is what we want here, because dom0 handles creation of qubes. Add `--skip-dom0` if you want to skip dom0 and add `--targets=<targets>` to add something else.
[/details]

The plan:
|#|fedora 41|debian 12|minimal debian 13|
|:-:|:--|:--|:--|
|0.|-|-|Prepare hvm template|
|1.|Prepare standalone|Prepare standalone|Prepare standalone|
|2.|Enable rpmfusion repositories|Add repository components|Add repository components|
|3.|Grow `/tmp/`, because default 1G is too small to fit everything that driver building process spews out. According to my measurement, driver no longer needs more than 1G to build. I have decided to leave this step in just in case this problem still occurs with different hardware.|-|-|
|4.|Install drivers & wait for build|Update, upgrade, install drivers|Update, upgrade, install drivers|
|5.|Delete X config, because we don't need it where we going :sunglasses:|-|-|
|6.|**optional** : Disable nouveau, because nvidia install script may fail to convince the system that it should use nvidia driver.|-|-|
|7.|**optional** : Install a script for running programs in prime-accelerated environment|same|same|

> :exclamation: Please be aware that both debian and rpmfusion driver package names may be different depending on what graphics card you have. This guide uses most common modern package names, but you should check it for yourself. This guide also assumes that you are starting from default qubes templates - Debian installation process changes if dracut or SecureBoot are used by the system.
>
> :thinking: Debian has `nvidia-detect` program to tell you which drivers you need. I should be able to parse it in a state to create a truly hardware-agnostic formula.

## 2-0.5. How to choose target *inside* the state file

Unless you are willing to write (and call for) multiple states to perform one operation, you might be wandering how to make salt apply only first state (qube creation) to dom0, and all others - to the nvidia qube. The answer is to use jinja:
```
{% if grains['id'] == 'dom0' %}

<!-- Dom0 stuff goes here -->

{% elif grains['id'] == nvd_f41['standalone']['name'] %}

<!-- nvd_f41['standalone']['name'] stuff goes here -->

{% endif %}
```

That way, state will be applied to all targets (dom0, prefs.standalone.name), but jinja will edit the state file appropriately for each of them.

## 2. Configure repositories

[details="fedora 41"]
Pretty self-explanatory. `{free,nonfree}` is used to enable multiple repositories at once. It is a feature of the shell, not salt or jinja.
```yaml
nvidia-driver--enable-repo:
  cmd.run:
    - name: dnf config-manager setopt rpmfusion-{free,nonfree}{,-updates}.enabled=1
```
[/details]

[details="debian 12 / debian 13"]
In order to configure Debian repository components, I use the [pkgrepo state](https://docs.saltproject.io/en/latest/ref/states/all/salt.states.pkgrepo.html#module-salt.states.pkgrepo).

Replace `<release>` with the release you're working with. `bookworm` for debian 12, `trixie` for debian 13.
```yaml
nvidia-driver--enable-repo:
  pkgrepo.managed:
    - name: deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian <release> main contrib non-free non-free-firmware
    - file: /etc/apt/sources.list
```
[/details]

## 3. Extend `/tmp/`

This lasts until reboot. As I already mentioned, you might not need this. On the other hand, it is non-persistent and generally harmless, so why not? 
```yaml
nvidia-driver--extend-tmp:
  cmd.run:
    - name: mount -o remount,size=2G /tmp/
```

## 4. Install drivers

Here, I use `- require:` parameter to wait for other states to apply before installing the drivers. Note that it needs both state (e.g. `cmd`) and label to function.

[details="fedora 41"]
```yaml
nvidia-driver--install:
  pkg.installed:
    - pkgs:
      - akmod-nvidia
      - xorg-x11-drv-nvidia-cuda
      {# - vulkan #}
    - require:
      - pkgrepo: nvidia-driver--enable-repo
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
```

In case of fedora I also use `loop.until_no_eval` to wait until driver is done building. It runs the state specified by `- name:` until it returns stuff from `- expected`. Here it is set to try once in 20 seconds for 600 seconds. `- args:` describe what to pass to the state in the `- name:`
Essentially, it runs `modinfo -F name nvidia`, which translates into "What is the name of the module with the name 'nvidia'?". It just returns an error until module is present (i.e. done building), and then returns 'nvidia'.
[/details]

[details="debian 12 / debian 13"]
```yaml
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
```
Technically, apt only needs to update metadata before installing, but I also run upgrade because the default debian template is pretty far behind.

`mesa-utils` contain mesa tools, technically we don't need them (thus the comment), but they contain `glxinfo`, which might be useful for debugging.
[/details]

## 5. Delete X config

```
nvidia-driver--remove-conf:
  file.absent:
    - name: {{ nvd_f41['paths']['nvidia_conf'] }}
    - require:
      - loop: nvidia-driver--assert-install
```

## 6. Disable nouveau

If you download state files, you will find it in a separate file. It is done so for two reasons:
1. It may not be required
1. I think vm must be restarted before this change is applied, so first run the main state and apply this after restarting the qube.

```yaml
{% if nvd_f41 is not defined %}
{% from 'nvidia-driver/default.jinja' import nvd_f41 %}
{% endif %}

{% if grains['id'] == nvd_f41['standalone']['name'] %}

nvidia-driver.disable-nouveau--blacklist-nouveau:
  file.append:
    - name: {{ nvd_f41['paths']['grub_conf'] }}
    - text: 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX rd.driver.blacklist=nouveau"'

nvidia-driver.disable-nouveau--grub-mkconfig:
  cmd.run:
    - name: grub2-mkconfig -o {{ nvd_f41['paths']['grub_out'] }}
    - require:
      - file: nvidia-driver.disable-nouveau--blacklist-nouveau

{% endif %}
```
Make sure to change the paths if you're not running fedora 41.

## 7. Install prime script

[Prime](https://wiki.archlinux.org/title/PRIME) is a technology used to manage hybrid graphics. For example, to offload render tasks to a powerful GPU despite it not having the monitor connected to it directly. Good real-world example of this is a gaming laptop. They generally have built-in displays connected directly to the CPU, but use Prime in order to render things like videogames effectively. NVIDIA implementation of Prime is called Optimus.

"Configuration" of Optimus Prime is extremely simple. Everything you need to offload rendering tasks to your GPU after installing the drivers is to set two environment variables.

Still, there's a little caveat: we generally don't want to offload *everything* to the GPU, therefore we can't just set the variables globally. In this case I'm using a simple bash script to execute commands in a correct environment:

```bash
#!/usr/bin/env bash

set -o errexit
set -o errtrace

(
  export __NV_PRIME_RENDER_OFFLOAD=1
  export __GLX_VENDOR_LIBRARY_NAME=nvidia

  $@
)
```

This script runs all arguments given to it in a subshell (`()`) with exported environment variables. This way the program is accelerated, but the environment doesn't persist when you get the prompt back.

To install it, I use the following state:
```
nvidia-driver--prime:
  file.managed:
    - name: /home/user/.local/bin/nvrun
    - source: {{ script['nvrun'] }}
    - user: user
    - group: user
    - mode: 700
    - makedirs: True
```

It saves the script to `/home/user/.local/bin/nvrun`. This location is special since it is examined as part of the $PATH. Executable files stored there can be ran just as any other command on your system, without specifying the path to it.

### Confirm that prime is working correctly

Good way to confirm that our prime script is working correctly is to execute `glxinfo -B` (part of mesa-utils) and check it's output. When ran by itself, it returns something like `llvmpipe (LLVM <version> ...)` in `OpenGL renderer string`. If your prime setup works correctly, running `nvrun glxinfo -B` results in your nvidia card showing up in the aforementioned field.

# Downloads
## Current version

- [github](https://github.com/RandyTheOtter/nvidia-driver/tree/main)
- [codeberg](https://codeberg.org/otter2/nvidia-driver)

Contributions, improvements and fixes are welcome! I call it GPL-3 if you need that for some reason.

# See also / References

- [Nvidia Graphics Drivers - Debian Wiki](https://wiki.debian.org/NvidiaGraphicsDrivers)
- [Howto/NVIDIA - RPM Fusion](https://rpmfusion.org/Howto/NVIDIA?highlight=%28%5CbCategoryHowto%5Cb%29)
- [Mesa - Debian Wiki](https://wiki.debian.org/Mesa)
- [Nvidia Optimus - Debian Wiki](https://wiki.debian.org/NVIDIA%20Optimus)
- [PRIME - Arch Linux Wiki](https://wiki.archlinux.org/title/PRIME)
- [Minimal Templates - QubesOS Documentation](https://doc.qubes-os.org/en/latest/user/templates/minimal-templates.html)
- [Salt Module Index](https://docs.saltproject.io/en/latest/py-modindex.html)
- [Jinja Documentation](https://jinja.palletsprojects.com/en/stable/templates/)
- [Understanding Jinja (Salt Documentation)](https://docs.saltproject.io/en/latest/topics/jinja/index.html)
- Countless posts on the [QubesOS forum](https://forum.qubes-os.org)
