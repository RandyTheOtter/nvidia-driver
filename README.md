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
