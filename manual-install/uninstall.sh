#!/bin/sh
# ==============================================================
# UU 游戏加速器 —— 卸载脚本（对应 install.sh 手动装的文件）
# 用法：sh /tmp/uu-booster-luci/manual-install/uninstall.sh
# ==============================================================
set -e

echo "==> 停止并卸载 UU 加速器（手动安装版）"

# 1. 停止并禁用服务
[ -x /etc/init.d/uugamebooster ] && {
	/etc/init.d/uugamebooster stop 2>/dev/null || true
	/etc/init.d/uugamebooster disable 2>/dev/null || true
}

# 2. 删除二进制 / 配置 / init
rm -f /usr/bin/uugamebooster \
      /usr/bin/xtables-nft-multi \
      /usr/bin/xuplugin-guardian \
      /etc/init.d/uugamebooster \
      /etc/config/uugamebooster \
      /usr/lib/lua/luci/i18n/uugamebooster.zh-cn.lmo
rm -rf /usr/share/uugamebooster

# 3. 删除 LuCI 页面文件
rm -f /www/luci-static/resources/view/uugamebooster.js \
      /usr/share/luci/menu.d/luci-app-uugamebooster.json \
      /usr/share/rpcd/acl.d/luci-app-uugamebooster.json
rm -rf /www/uugamebooster

# 4. 设备标识（若已生成则一并删除，会解绑）
rm -f /.uuplugin_uuid

# 5. 刷新服务
rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

echo "==> 卸载完成。刷新浏览器 (Ctrl+F5)，LuCI 里的『UU GameAcc』应该已消失。"
