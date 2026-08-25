# openwrt-autobuild

个人用的 OpenWrt 自动构建仓库：跟踪几个主流第三方源，上游有更新时自动编译 x86_64 固件并发布。

> **非官方构建。** 产物由本仓库的 GitHub Actions 自动编译，与各上游项目官方发布无关，也未经上游审核。追求稳妥请直接使用上游官方发布版本。

## 构建内容

| 源 | 上游 | 跟踪分支 | 配置 |
|---|---|---|---|
| Lean's LEDE | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) | `master` | 完整（含 passwall / ssr-plus / docker / argon） |
| ImmortalWrt | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) | `master` | 同上 |
| Lienol's OpenWrt | [Lienol/openwrt](https://github.com/Lienol/openwrt) | `25.12` | 精简基线 |
| Official OpenWrt | [openwrt/openwrt](https://github.com/openwrt/openwrt) | `main` | 精简基线 |

目标平台统一为 **x86_64 generic + EFI**。

两档配置是按各源实际提供的包定的，不是拍脑袋：`luci-app-passwall`、`luci-theme-argon`、`luci-app-syncdial` 只存在于 lede 和 ImmortalWrt 的 luci feed 里，Lienol 和官方源都没有，所以后两者走精简基线，只包含四个源都确实提供的包（`luci-app-dockerman`、`mwan3`、`ttyd`、`frpc` 等）。

给 Lienol 和官方源硬挂第三方代理 feed 是可以做到的，但那正是版本错配拖垮构建的典型来源 —— 这两个源在这里的价值恰恰是干净基线。

## 工作流

`autobuild-openwrt.yml` — 每月 1、15 号 02:00 (UTC+8)，也可手动触发。

三个 job：

1. **check-upstream** — 用 `git ls-remote` 把每个源的分支 tip 解析成 commit SHA，和 `upstream.lock` 比对，只把真正动过的源放进构建矩阵。一次网络往返就能判断，不必为此 clone 几百 MB 的源码树。
2. **build** — 矩阵并行，`fail-fast: false`，一个源挂掉不影响其余三个的结果可见性。源码 clone 后 **detach 到解析阶段记录的那个 SHA**，保证 release 里写的 commit 和实际编译的代码永远一致。
3. **record** — 只把**构建成功**的源的 SHA 写回 `upstream.lock`。失败的源保留旧 SHA，下次定时运行会重试，而不是被当成"没更新"跳过。

手动触发支持两个参数：

- `force_build` — 无视 `upstream.lock`，强制全部重编
- `only` — 逗号分隔的源 id，例如 `lede,openwrt`

新增一个源只要往 `sources.json` 加一条记录，再配一份 `config/<id>.config`。

## 可追溯性

每个 Release 的说明里都带上游仓库、分支和完整 commit SHA（附链接）。`upstream.lock` 记录每个源最后一次**成功构建**的 commit，因此任何一份固件都能精确定位到它对应的上游代码。

每个源保留最近 3 个 Release，更早的自动清理。

## 已知的坑（都已在工作流里处理）

- **依赖必须写死在工作流里。** 上游模板用的 `curl -fsSL git.io/depends-ubuntu-1804` 早已失效（git.io 2022 年关停）：`curl -f` 失败返回空，`apt-get install` 空参数退出码为 0，于是步骤显示绿色，而整个构建在缺依赖的环境里跑。
- **必须删掉 runner 上的 `/usr/local/bin/runc`。** moby 的 `hack/make/binary-daemon` 只要检测到这个文件存在，就会去拷贝宿主机的 `docker-init` / `rootlesskit` / `dockerd-rootless.sh`，而 runner 上并没有这几个，`cp ''` 直接报错并拖垮 `dockerd` 包。删掉 runc 后该逻辑提前返回；`docker-proxy` 由独立的 `binary-proxy` 目标产出，不受影响。
- **Node 20 将于 2026-09-16 从 runner 移除**，所有 action 都固定在 node24 的大版本上，且用 tag 而非 `@main`。
- **编译失败时不发布 release。** organize / tag / release 全部以编译真正成功为前提，否则会产出只有几个 `.buildinfo` 文件的空 release。
- 编译失败时自动上传 `openwrt/logs`，事后排查不必依赖 90 天的日志保留期。

## 许可

本仓库自身的构建脚本与工作流配置以 MIT 许可发布，见 [LICENSE](LICENSE)。

Release 中的固件是上述上游项目的编译结果，各自沿用其原始许可证（OpenWrt 及其软件包以 GPL-2.0 等许可分发）。对应源码可通过 Release 说明中记录的 commit SHA 精确定位到上游公开仓库。本仓库未对上游源码做任何修改。
