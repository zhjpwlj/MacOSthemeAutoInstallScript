name: Test sh script through github actions

on:
  workflow_dispatch

jobs:
  execute-script:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install minimal GNOME components & pipx
        env:
          DEBIAN_FRONTEND: noninteractive
        run: |
          sudo apt-get update
          # 安全に隔離インストールできる pipx を使用します
          sudo apt-get install -y --no-install-recommends gnome-shell xvfb dbus-x11 pipx

      - name: Install gnome-extensions-cli via pipx
        run: |
          # システム環境を汚さずに gext をインストール
          pipx install gnome-extensions-cli --force

      - name: Execute script inside virtual desktop session
        run: |
          chmod +x ./ubuntu-human.sh
          
          # 【重要】pipx が作成したバイナリの場所を直接環境変数の先頭に追加します
          export PATH="$HOME/.local/bin:$PATH"
          
          echo "=== Testing gext version ==="
          dbus-run-session -- xvfb-run --server-num=99 -s "-ac" gext --version
          
          echo "=== Running script ==="
          dbus-run-session -- xvfb-run --server-num=99 -s "-ac" ./ubuntu-human.sh
