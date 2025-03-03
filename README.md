# nvidia-driver
Salt formulas to deploy NVIDIA hardware-accelerated qubes with cuda support

## Contents

- `nvidia-driver/`:
  - `f41.sls` - deploy fedora-41 qube
  - `f41-disable-nouveau.sls` - disables nouveau (use if nvidia driver isn't prioritized upon installation and reboot)
  - `d12.sls` - deploy debian-12 qube
  - `any-minimize-swap.sls` - set swappiness to 0

## How to use

1. Upload `nvidia-driver` to your salt environment
2. Review config in `default.jinja`
3. Use states:
  - Directly: `sudo qubesctl --show-output --targets <target_name> state.sls nvidia-driver.f41 saltenv=user`
  - In another formula `{% include 'nvidia-driver/f41.sls' %}`

## Current tasks

- [x] Fedora version
- [x] Debian version
- [ ] optimus prime
