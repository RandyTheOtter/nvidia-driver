# nvidia-driver
Salt formulas to deploy hardware-accelerated qubes.

## Contents

- `nvidia-driver/`:
  - `f41.sls` - deploy fedora-41 qube
  - `f41-disable-nouveau.sls` - disables nouveau (use if nvidia driver isn't prioritized upon installation and reboot)
  - `d12.sls` - deploy debian-12 qube

## How to use

1. Upload `nvidia-driver` to your salt environment
2. Review config in `default.jinja`
3. `sudo qubesctl --show-output --targets <target_name> state.sls nvidia-driver.f41 saltenv=user` **or** `{% include 'nvidia-driver/f41.sls' %}`

## Current tasks

- [x] Fedora version
- [x] Debian version
- [ ] optimus prime
