# nvidia-driver

Salt formulas for deployment of NVIDIA hardware-accelerated qubes with cuda support

## Contents

- `nvidia-driver/`:
  - `default.jinja` - configuration variables
  - `d12.sls` - deploy debian-12 qube
  - `d13m` - states for deployment of debian-13 qubes
    - `template.sls` - prepare hvm-capable minimal template
    - `standalone.sls` - create a standalone based on an hvm-capable template. Will work with `debian-13-xfce` as well as with `debian-13-minimal-hvm` created by `template.sls`
  - `f41.sls` - deploy fedora-41 qube
  - `f41-disable-nouveau.sls` - disables nouveau (use if nvidia driver isn't prioritized upon installation and reboot)
  - `any-minimize-swap.sls` - set swappiness to 0
  - `any-prime.sls` - install prime script into `.local/bin/` of the `user`. Execute `nvrun myprogram` to accelerate `myprogram` with prime.

## How to use

1. Upload `nvidia-driver` to your salt environment
2. Review config in `default.jinja`
3. Use states:
  - Directly: `sudo qubesctl --show-output --targets <target_name> state.sls nvidia-driver.f41 saltenv=user`
  - In another formula `{% include 'nvidia-driver/f41.sls' %}`

These states also support providing your own variables (as opposed to the ones in `default.jinja`). If jinja sees appropriately named variable in the context it won't import the same variable from `default.jinja`.

## Current tasks

- [x] optimus prime
- [x] debian 13
- [ ] fedora 42

far future:
- [ ] rpm repository

## Mirrors

- https://github.com/RandyTheOtter/nvidia-driver
- https://codeberg.org/otter2/nvidia-driver
