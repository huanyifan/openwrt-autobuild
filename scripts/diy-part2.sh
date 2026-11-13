#!/bin/bash
# Shared post-feed customisation. Runs inside the source tree, after
# `feeds install` and after .config is in place.

# Default LAN address.
sed -i 's/192.168.1.1/192.168.31.111/g' package/base-files/files/bin/config_generate

# Fix host tools paths (e.g. helloworld's mihomo calling hardcoded $(STAGING_DIR_HOST)/bin/upx)
find feeds/ package/feeds/ -name "Makefile" -exec sed -i 's|\$(STAGING_DIR_HOST)/bin/upx|upx|g' {} + 2>/dev/null || true

# Pre-populate host binaries into staging dirs so build steps finding tools directly won't fail
mkdir -p staging_dir/host/bin staging_dir/hostpkg/bin
command -v upx >/dev/null 2>&1 && ln -sf "$(command -v upx)" staging_dir/host/bin/upx && ln -sf "$(command -v upx)" staging_dir/hostpkg/bin/upx
command -v ninja >/dev/null 2>&1 && ln -sf "$(command -v ninja)" staging_dir/host/bin/ninja && ln -sf "$(command -v ninja)" staging_dir/hostpkg/bin/ninja

# Skip mirror hash verification for helloworld packages to prevent upstream git archive hash drift
if [ -d "feeds/helloworld" ]; then
  find feeds/helloworld/ -name "Makefile" -exec sed -i 's/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=skip/' {} + 2>/dev/null || true
  find feeds/helloworld/ -name "Makefile" -exec sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/' {} + 2>/dev/null || true
fi
