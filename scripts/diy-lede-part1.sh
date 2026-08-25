#!/bin/bash
# Feed setup for coolsnowwolf/lede. Runs inside the source tree, before
# `feeds update`.

# luci-app-ssr-plus lives in the helloworld feed, which lede ships commented out.
sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# luci-app-passwall comes from lede's own luci feed. Lienol/openwrt-package no
# longer carries passwall, so it is deliberately NOT added here.
