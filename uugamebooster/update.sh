#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Copyright (C) 2021 ImmortalWrt.org
#
# 用途: 把 uugamebooster 包升级到网易 UU 官方最新版本。
#       查询官方 API 拿到最新版本号，下载 4 个架构的 uu.tar.gz，
#       计算 sha256 后写回 Makefile 的 PKG_VERSION 与 PKG_HASH。
#
# 用法: 在 uugamebooster/ 目录下执行  ./update.sh

set -euo pipefail

CURDIR="$(cd "$(dirname "$0")" && pwd)"
MK="$CURDIR/Makefile"

API="https://router.uu.163.com/api/plugin?type=openwrt"
DL="https://uurouter.gdl.netease.com/uuplugin/openwrt"

# 各架构版本一致，用 aarch64 的接口取版本号
json="$(curl -fsSL "${API}-aarch64")"
version="$(printf '%s' "$json" | sed -n 's/.*\/v\([0-9][0-9.]*\)\/uu\.tar\.gz.*/\1/p' | head -n1)"
if [ -z "$version" ]; then
	echo "ERROR: 无法从官方 API 解析版本号" >&2
	exit 1
fi

current="$(sed -n 's/^PKG_VERSION:=\(.*\)$/\1/p' "$MK" | tr -d ' \t')"
echo "当前 Makefile 版本: ${current:-<无>}"
echo "最新官方版本:       $version"

for arch in aarch64 arm mipsel x86_64; do
	tmp="$(mktemp)"
	curl -fsSL "${DL}-${arch}/v${version}/uu.tar.gz?" -o "$tmp"
	sha="$(sha256sum "$tmp" | awk '{print $1}')"
	rm -f "$tmp"
	echo "  $arch: $sha"

	# 更新紧随 "($(ARCH),<arch>)" 一行的 PKG_HASH
	line="$(grep -n "(\$(ARCH),$arch)" "$MK" | cut -d: -f1)"
	if [ -z "$line" ]; then
		echo "ERROR: 在 Makefile 中找不到 $arch 的架构行" >&2
		exit 1
	fi
	sed -i "$((line + 1))s/PKG_HASH:=.*/PKG_HASH:=$sha/" "$MK"
done

sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$version/" "$MK"
echo "Makefile 已更新到 v$version。"
