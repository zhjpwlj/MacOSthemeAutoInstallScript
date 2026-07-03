#!/bin/bash

# 1. パッケージリストの更新
sudo apt update

# 2. 全パッケージ名の取得
# 競合を避けるため、1つずつ安全にインストールを試行
apt-cache pkgnames | while read -r pkg; do
    echo "Installing: $pkg"
    # --yes: 自動承認
    # --fix-broken: 依存関係の破損を自動修復
    sudo apt-get install --yes --fix-broken "$pkg"
done
