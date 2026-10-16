#!/bin/sh
# ==============================================================
# UU 游戏加速器 —— 免编译直接安装脚本（在路由器上执行）
#
# 不需要搭建 OpenWrt 编译环境，直接把文件传到路由器上装。
#
# 用法：
#   1) 把整个 uu-booster-luci 目录传到路由器，例如：
#        scp -r uu-booster-luci root@192.168.1.1:/tmp/
#   2) 在路由器上执行：
#        sh /tmp/uu-booster-luci/manual-install/install.sh
#
# 依赖：curl / wget / uclient-fetch（三者有其一即可，路由器一般自带）
# ==============================================================
set -e

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SELF_DIR/.." && pwd)"

# 二进制版本（与 uugamebooster/Makefile 的 PKG_VERSION 保持一致）
VERSION="${UU_VERSION:-14.9.4}"

echo "==> UU 加速器免编译安装 v$VERSION"

# --------------------------------------------------------------
# 1. 检测架构
# --------------------------------------------------------------
detect_arch() {
	local a
	if [ -r /etc/openwrt_release ]; then
		a="$(sed -n "s/^DISTRIB_ARCH=['\"]*\([^'\"]*\).*/\1/p" /etc/openwrt_release)"
	fi
	[ -n "$a" ] || a="$(uname -m)"

	case "$a" in
		aarch64*|arm64*)        echo "aarch64" ;;
		arm*)                   echo "arm" ;;
		mipsel*)                echo "mipsel" ;;
		mips*)                  echo "mipsel" ;;   # 常见的是 MT7621(mipsel)，大端 mips 官方也不支持
		x86_64*|amd64*)         echo "x86_64" ;;
		*)                      echo "" ;;
	esac
}

ARCH="$(detect_arch)"
if [ -z "$ARCH" ]; then
	echo "!! 无法确定你的路由器架构，请手动运行:  uname -m"
	echo "   然后把结果对应的 aarch64/arm/mipsel/x86_64 通过环境变量传入，例如："
	echo "   UU_ARCH=arm sh $0"
	exit 1
fi
[ -n "$UU_ARCH" ] && ARCH="$UU_ARCH"
echo "   检测到架构: $ARCH"

# --------------------------------------------------------------
# 2. 下载官方 uuplugin 二进制（如本地已有同名包则跳过）
# --------------------------------------------------------------
TARBALL="$SELF_DIR/uu-$ARCH.tar.gz"

fetch() {
	# $1 = url, $2 = 目标文件
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$1" -o "$2"
	elif command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1"
	else
		return 1
	fi
}

if [ ! -f "$TARBALL" ]; then
	echo "   下载 uuplugin (openwrt-$ARCH v$VERSION)..."
	fetch "https://uurouter.gdl.netease.com/uuplugin/openwrt-$ARCH/v$VERSION/uu.tar.gz?" "$TARBALL" \
		|| { echo "!! 下载失败，请确认路由器能访问外网"; exit 1; }
else
	echo "   使用本地已存在的 $TARBALL"
fi

# --------------------------------------------------------------
# 3. 解压并安装二进制 / 配置
# --------------------------------------------------------------
TMP="$(mktemp -d)"
tar xzf "$TARBALL" -C "$TMP"

echo "   安装二进制..."
mkdir -p /usr/bin /usr/share/uugamebooster
cp -f "$TMP/uuplugin" /usr/bin/uugamebooster
chmod 0755 /usr/bin/uugamebooster

if [ -f "$TMP/xtables-nft-multi" ]; then
	cp -f "$TMP/xtables-nft-multi" /usr/bin/xtables-nft-multi
	chmod 0755 /usr/bin/xtables-nft-multi
fi

# uuplugin 的看门狗进程，必须和 uuplugin 放在同一目录，否则启动报
# "stat failed /usr/bin/./xuplugin-guardian / execl failed"
if [ -f "$TMP/xuplugin-guardian" ]; then
	cp -f "$TMP/xuplugin-guardian" /usr/bin/xuplugin-guardian
	chmod 0755 /usr/bin/xuplugin-guardian
fi

cp -f "$TMP/uu.conf" /usr/share/uugamebooster/uu.conf
rm -rf "$TMP"

# --------------------------------------------------------------
# 4. 安装 init 脚本 + UCI 配置
# --------------------------------------------------------------
echo "   安装 init 脚本与 UCI 配置..."
mkdir -p /etc/init.d /etc/config
cp -f "$ROOT_DIR/uugamebooster/files/uugamebooster.init" /etc/init.d/uugamebooster
chmod 0755 /etc/init.d/uugamebooster
[ -f /etc/config/uugamebooster ] || \
	cp -f "$ROOT_DIR/uugamebooster/files/uugamebooster.config" /etc/config/uugamebooster

# --------------------------------------------------------------
# 5. 安装 LuCI 静态文件 + 中文翻译
# --------------------------------------------------------------
echo "   安装 LuCI 界面文件..."
LUCI="$ROOT_DIR/luci-app-uugamebooster"
mkdir -p /www/luci-static/resources/view \
         /usr/share/luci/menu.d \
         /usr/share/rpcd/acl.d \
         /www/uugamebooster \
         /usr/lib/lua/luci/i18n

cp -f "$LUCI/htdocs/luci-static/resources/view/uugamebooster.js" /www/luci-static/resources/view/uugamebooster.js
cp -f "$LUCI/root/usr/share/luci/menu.d/luci-app-uugamebooster.json" /usr/share/luci/menu.d/
cp -f "$LUCI/root/usr/share/rpcd/acl.d/luci-app-uugamebooster.json" /usr/share/rpcd/acl.d/
cp -f "$LUCI/root/www/uugamebooster/uuios.png"     /www/uugamebooster/
cp -f "$LUCI/root/www/uugamebooster/uuandriod.png" /www/uugamebooster/
[ -f "$SELF_DIR/uugamebooster.zh-cn.lmo" ] && \
	cp -f "$SELF_DIR/uugamebooster.zh-cn.lmo" /usr/lib/lua/luci/i18n/

# --------------------------------------------------------------
# 6. 刷新 LuCI / rpcd
# --------------------------------------------------------------
echo "   刷新服务..."
/etc/init.d/uugamebooster enable 2>/dev/null || true
rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

echo
echo "=============================================================="
echo " 安装完成！"
echo
echo " 下一步（二选一）："
echo "   A) 浏览器打开 LuCI，到『服务 -> UU GameAcc』，把『启用』打开并保存&应用；"
echo "   B) 命令行直接开启："
echo "        uci set uugamebooster.config.enabled=1"
echo "        uci commit uugamebooster"
echo "        /etc/init.d/uugamebooster restart"
echo
echo " 注意：如果 LuCI 页面还是旧的，请强制刷新浏览器 (Ctrl+F5)。"
echo " 开启后用手机『UU主机加速』App 扫码绑定本路由器即可。"
echo "=============================================================="
