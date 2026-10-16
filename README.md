# UU 游戏加速器（网易 UU）for ImmortalWrt / OpenWrt 25.12+

给路由器装一个「UU 游戏加速器」：包括官方 `uuplugin` 二进制包和一个 LuCI 管理界面。
开启后，用手机上的「UU 主机加速」App 扫码绑定这台路由器，即可给 PS / Xbox / Switch / 主机游戏加速。

> 说明：`uuplugin` 是网易官方的闭源二进制，本仓库只负责**下载 + 打包 + 提供 init 脚本和 LuCI 界面**，
> 不会也不应该修改其内容。二进制由 `uugamebooster` 包在编译时从网易官方 CDN 拉取。

---

## 目录结构

```
uu-booster-luci/
├── manual-install/             # 免编译直接安装（在路由器上跑）
│   ├── install.sh              #   一键安装脚本
│   └── uugamebooster.zh-cn.lmo #   预编译的中文翻译
├── uugamebooster/              # 二进制包（下载官方 uuplugin + init + UCI 配置）
│   ├── Makefile
│   ├── update.sh               # 一键升级到官方最新版本的脚本
│   └── files/
│       ├── uugamebooster.init  # procd 启动脚本
│       └── uugamebooster.config# UCI 默认配置
└── luci-app-uugamebooster/     # LuCI 前端（Web 管理页）
    ├── Makefile
    ├── htdocs/.../uugamebooster.js   # 前端页面（client-side JS）
    ├── po/zh_Hans/...                # 中文翻译
    └── root/
        ├── usr/share/luci/menu.d/... # 菜单项
        ├── usr/share/rpcd/acl.d/...  # 权限（ACL）
        └── www/uugamebooster/        # 二维码图片
```

---

## 兼容性

- 面向 **OpenWrt 25.12+ / ImmortalWrt（apk 包管理）**，LuCI 采用新的 client-side JS 前端。
  - 如果你是 **24.10 及更早（opkg + 旧 LuCI）**，本目录的 LuCI 前端不适用（那是 Lua CBI 写法），
    需要用旧分支版本。
- 依赖 `kmod-tun`（UU 加速走 TUN 隧道），会作为依赖自动装上。

## 支持架构

| 路由器 `uname -m` | 本包 ARCH |
|---|---|
| `aarch64` | aarch64 |
| `armv7l` / `armv6l` | arm |
| `mipsel` | mipsel |
| `x86_64` | x86_64 |

在路由器上执行以下命令确认：

```sh
uname -m
```

> 大端 `mips`（很老的路由器）等不在官方支持列表内，会直接装不上 / menuconfig 里看不到。

---

## 安装方式总览

**不用「编译进固件核心」**，你有三种装法，按省事程度排序：

| 方式 | 需要编译环境？ | 说明 |
|---|---|---|
| **A. 免编译直接安装** | ❌ 不需要 | 把文件夹传到路由器，跑一个 `install.sh` 脚本即可（见下） |
| **B. SDK 只编译出 .apk** | ✅ 需要 SDK | 不编译整个固件，只把这两个包打成 `.apk` 再 `apk add` |
| **C. 编进固件** | ✅ 需要完整编译树 | menuconfig 里选 `<*>`，直接烧进固件 |

---

## 方式 A：免编译直接安装（最简单，推荐）

因为 `uuplugin` 是网易的**静态二进制**、LuCI 是**纯静态文件**，所以不需要任何编译环境，
直接把文件传到路由器上装就行：

```sh
# 在你的电脑上，把整个目录传到路由器
scp -r uu-booster-luci root@192.168.1.1:/tmp/

# 然后 SSH 到路由器上执行
sh /tmp/uu-booster-luci/manual-install/install.sh
```

脚本会自动：
1. 检测路由器架构（`aarch64` / `arm` / `mipsel` / `x86_64`）；
2. 从网易官方 CDN 下载对应架构的 `uuplugin` 二进制；
3. 装好二进制、init 脚本、UCI 配置、LuCI 页面和中文翻译；
4. 重启 rpcd/uhttpd 让界面生效。

装完后到 LuCI「服务 → UU GameAcc」打开「启用」即可；或命令行：

```sh
uci set uugamebooster.config.enabled=1
uci commit uugamebooster
/etc/init.d/uugamebooster restart
```

> 说明：`install.sh` 只做「解压安装」不重新编译任何东西；二进制版本写死在脚本头部
> 的 `VERSION`（默认 `14.9.4`，和 `uugamebooster/Makefile` 一致），要换版本就改那个变量。
> 脚本需要路由器能连外网（下载二进制），且 `curl` / `wget` / `uclient-fetch` 至少有一个。

---

## 方式 B / C：编译安装

### 一、把包放进你的编译树

方法 ①（最简单）：把两个包目录复制到编译树的 `package/` 下：

```sh
cd /path/to/immortalwrt
cp -r /path/to/uu-booster-luci/uugamebooster package/
cp -r /path/to/uu-booster-luci/luci-app-uugamebooster package/
```

方法 ②：做成本地 feed（适合放进你自己的 feed 仓库），把整个目录结构放到 feed 下，
然后在 `feeds.conf` 里加一行 `src-link` 或 `src-git` 指向它，再：

```sh
./scripts/feeds update -a
./scripts/feeds install -a
```

---

### 二、menuconfig 里勾选

```sh
make menuconfig
```

```
LuCI  --->
  Applications  --->
    <*> luci-app-uugamebooster
```

`luci-app-uugamebooster` 依赖 `uugamebooster`，勾选前者会自动带上后者。
（如果你的架构不受支持，这个包会直接不显示。）

---

### 三、编译

```sh
make package/luci-app-uugamebooster/compile V=s
# 或全量编译
make -j$(nproc) V=s
```

产物在 `bin/packages/<arch>/` 下，会生成 `.apk` 文件：

- `luci-app-uugamebooster_*.apk`
- `uugamebooster_*.apk`

---

### 四、安装（.apk）

把两个 `.apk` 传到路由器，用 apk 安装：

```sh
apk add --allow-untrusted ./uugamebooster_*.apk
apk add --allow-untrusted ./luci-app-uugamebooster_*.apk
```

或者直接在编译时把包编进固件（menuconfig 里选 `<*>` 而不是 `<M>`）。

装完后刷新 LuCI（或重启路由器），在 **服务 → UU GameAcc** 就能看到管理页。

---

## 使用

1. 进入 LuCI 的「服务 → UU GameAcc」，把「启用」打开并**保存&应用**，状态会变成绿色「运行中」。
2. 用手机扫描页面里的二维码，下载「UU 主机加速」App（iOS / Android）。
3. 在 App 里**绑定本台路由器**（App 会通过局域网自动发现，或手动指定路由器 IP）。
4. 在 App 里选择要加速的主机 / 游戏主机，开始加速。

> 首次绑定时，`uuplugin` 会在路由器根目录生成 `/.uuplugin_uuid` 作为设备标识，
> 该文件已在包的 `conffiles` 里声明，升级/重装包时不会被覆盖。

---

## 升级插件到官方最新版

网易会不定期更新 `uuplugin`。升级只需在**编译主机**上执行：

```sh
cd /path/to/uu-booster-luci/uugamebooster
./update.sh
```

脚本会自动：
1. 查询官方 API 拿最新版本号；
2. 下载 4 个架构的 `uu.tar.gz` 并计算 sha256；
3. 写回 `Makefile` 的 `PKG_VERSION` 与 `PKG_HASH`。

之后重新编译即可。脚本依赖 `curl`、`sha256sum`、`sed`（Linux 上都有）。

---

## 注意事项

- `uuplugin` 是**网易官方闭源二进制**，需要联网与网易服务器通信；加速功能需要网易 UU 会员。
- 25.12 起 OpenWrt 默认用 nftables（fw4），包内会把官方自带的 `xtables-nft-multi`
  装到 `/usr/bin/xtables-nft-multi` 以兼容 uuplugin 的 iptables 调用，请勿手动删除。
- 页面里的两张二维码图片（`uuios.png` / `uuandriod.png`）是网易 UU App 的下载二维码，
  随包提供；如官方二维码更新，替换 `luci-app-uugamebooster/root/www/uugamebooster/` 下的同名文件即可。
- 配置文件名是 `uugamebooster`（UCI），启动脚本是 `/etc/init.d/uugamebooster`，
  可手动用 `/etc/init.d/uugamebooster start|stop|restart|status` 管理。
