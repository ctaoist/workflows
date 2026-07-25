#!/bin/bash

# Modify default IP
sed -i 's/192.168.6.1/10.10.12.2/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

if [ -e vermagic_patch ]; then
  if git apply --check vermagic_patch; then
    git apply vermagic_patch
  elif git apply --reverse --check vermagic_patch; then
    echo "vermagic_patch is already applied"
  else
    echo "vermagic_patch is incompatible with the current source" >&2
    exit 1
  fi
fi
