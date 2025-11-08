#!/usr/bin/env bash

set -o errexit
set -o errtrace

if [ -f /etc/X11/xorg-qubes.conf ]
then
  mv /etc/X11/xorg-qubes.conf /etc/X11/xorg-qubes.conf.backup
fi
