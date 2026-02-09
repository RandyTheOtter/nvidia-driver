<!-- vim: sw=4 syntax=markdown:
-->
# nvidia-driver

Salt formula for deployment of NVIDIA hardware-accelerated qubes with cuda support

## Contents

```
.
├── doc
│   └── nvidia-driver.md        # Guide to this formula 
├── LICENSE
├── nvidia_driver
│   └── nvidia_driver
│       ├── create.sls          # Create template
│       ├── init.sls            # Install drivers
│       ├── nvrun               # Run a program in prime environment
│       ├── prime.sls           # Install prime environment script (nvrun)
│       └── zero_swap.sls       # Set swapiness to 0
├── pillar.example              # All available configuration parameters
└── README.md
```

## How to use

1. Upload `nvidia-driver` to your salt environment

    Any location defined in `file_roots` will work. Usually formulas are 
    installed in `/srv/formulas/`

    For example, if you install the formula like this: 

    ```
    /srv/formulas/
    └── nvidia_driver
        └── nvidia_driver
            ├── create.sls
            ├── init.sls
            ├── nvrun
            ├── prime.sls
            └── zero_swap.sls
    ```

    You should set the following `file_roots`:

    ```yaml
    file_roots:
      base:
        - /srv/salt
        - /srv/formulas/nvidia_driver
    ```

2. Configure top file

    This example assumes that you handle vm creation and configuration in dom0 
    separately, see `pillar.example` if you want `nvidia_driver.create` to make 
    templates for you.
    
    ```yaml
    # /srv/salt/top.sls
    base:
      debian-13-nv:
        - nvidia_driver
        - nvidia_driver.zero_swap

      fedora-42-nv:
        - nvidia_driver
        - nvidia_driver.prime
    ```

3. Apply the state

    Don't forget to add `--max-concurrency=1` if your vms operate the same
    devices to prevent them from "fighting" over it.

    ```console
    # qubesctl --targets debian-13-nv,fedora-42-nv state.highstate
    ```

## Current tasks

- [x] optimus prime
- [x] debian 13
- [x] fedora 42
- [x] generalize installation of drivers
- [ ] document usage via gitfs
    This could allow invocation of this formula without ever installing 
    anything in dom0 (with a slight drawback of not being able to use 
    nvidia_driver.create)
- [ ] Fail if distribuion is not supported
- [ ] Use list of dictionaries for `nvidia_driver.create` configuration
- [ ] Do whonix as well
- [ ] Automate driver package detection on debian
- [x] Test debian 14 and fedora 43 (it does not work)
- [ ] Update it to work on debian 14 and fedora 43

future, maybe:
- [ ] rpm repository

## Mirrors

- https://github.com/RandyTheOtter/nvidia-driver
- https://codeberg.org/otter2/nvidia-driver
