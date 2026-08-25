#!/bin/bash
# No feed changes.
#
# Lienol/openwrt and the official tree are built from their stock feeds on
# purpose: their value here is a clean baseline. Bolting third-party proxy
# feeds onto them invites the version skew that breaks builds, and both
# already carry luci-app-dockerman, mwan3, ttyd and frpc.
:
