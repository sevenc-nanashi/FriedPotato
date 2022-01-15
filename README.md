# FriedPotato：プロセカ創作譜面サーバー

https://potato.purplepalette.net に少しだけ機能を追加したサーバー。

## 追加機能

- 背景画像の追加
- 中間点の音変更
- 旧譜面変換

## 必須事項

- Ruby 3.0以上
- DXRubyが動く環境
- bundler

## 動かし方

1. [Rubyをインストールします。](https://rubyinstaller.org)[Ruby3.0.2、x86](https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.0.2-1/rubyinstaller-devkit-3.0.2-1-x64.exe)が推奨です。
2. [DXRubyの環境を整えます。](https://qiita.com/noanoa07/items/7df5886c619781d8d2ee#-d3dx9_40dll%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB%E6%96%B9%E6%B3%95)
3. PCを再起動します。
4. 右上のCodeボタンから`Download ZIP`でZipをダウンロードします。
5. 適当なところに解凍します。
6. `install.bat`を起動します。
7. `launch.bat`を起動します。
8. コントロールパネル→システムとセキリュティ→Windowsファイアウォール→詳細設定 を開きます。
9. 受信の規則→新規作成 を開きます。
10. TCPに設定し、ポート番号を4567にします。
11. 適当な名前をつけます。
12. 画面に出てきたサーバーに接続します。

2回目以降は`launch.bat`を動かせばサーバーを起動できます。

## ライセンス

GPLv3で公開しています。
