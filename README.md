# nvidia-driver
Salt formulas to deploy hardware-accelerated qubes.

## Contents

```
nvidia-driver/                                                                  
├── default.jinja                                                                    
├── f41-disable-nouveau.sls                                                          
└── f41.sls
```

`f41.sls` - deploy fedora-41 qube
`f41-disable-nouveau.sls` - disables nouveau (use if nvidia driver isn't prioritized upon installation and reboot)

## How to use

1. Upload `nvidia-driver` to your salt environment
2. Review config in `default.jinja`
3. `sudo qubesctl --show-output --targets <target_name> state.sls nvidia-driver.f41 saltenv=user` **or** `{% include 'nvidia-driver/f41.sls` %}`

## Current tasks

- [x] Fedora version
- [ ] Debian version
- [ ] optimus prime
