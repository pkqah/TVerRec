# :tv:**TVerRec**:tv: - TVer 一括ダウンロード -

TVerRecは、動画配信サイトTVer ( ティーバー <https://tver.jp/> ) の動画を録画保存するためのダウンローダー、ダウンロードツールです。
動画を1本ずつ指定してダウンロードするのではなく、動画のジャンルや出演タレントを指定して一括ダウンロードします。
ループ実行するようになっているので、1回起動すれば新しい番組が配信される都度ダウンロードされるようになります。
もちろん動画を1本ずつ指定したダウンロードも可能です。
また、ダウンロード保存した動画が正常に再生できるかどうかの検証も行い、動画ファイルが壊れている場合には自動的に再ダウンロードします。
動画の検証時にffmpegを使用しますが、可能な限りハードウェアアクセラレーションを使うので、CPU使用率を抑えることができます。(使用するPCでの性能によっては処理時間が長くなることがあります。その場合はハードウェアアクセラレーションを無効化できます)
動作に必要なyt-dlpやffmpegなどの必要コンポーネントは自動的に最新版がダウンロードされます。(Windowsのみ)

## 前提条件

Windows10とWindows11で動作確認していますが、おそらくWindows7、8でも動作します。
Windows PowerShell 5.1とPowerShell Core 7.2の双方で動作しています。おそらくそれ以外のVersionでも動作すると思います。
PowerShellはMacOS、Linuxにも移植されてるので動作するはずです。
一応、PowerShell 7.2をインストールしたRaspberry Pi OSでも動作確認をしています。([参考](https://docs.microsoft.com/ja-jp/powershell/scripting/install/install-raspbian?view=powershell-7.2))
MacOSでもPowerShellをインストールすれば動作するはずです。([参考](https://docs.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-macos?view=powershell-7.2))
yt-dlpの機能を活用しているため、日本国外からもVPNを使わずにダウンロードできます。

## 実行方法

以下の手順でバッチファイルを実行してください。

1. TVerRecをダウロードして任意のディレクトリで解凍、または`git clone`してください。
2. 以下を参照して環境設定、ダウンロード設定を行ってください。
3. Windows環境では `windows/start_tverrec.bat`を実行してください。
    - 処理が完了しても10分ごとに永遠にループして稼働し続けます。
    - 上記でPowerShellが起動しない場合は、PowerShell の実行ポリシーのRemoteSignedなどに変更する必要があるかもしれません。([参考](https://docs.microsoft.com/ja-jp/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2))
    - LinuxやMacOSも基本的に同じ使い方ですが、以下の章を参照してください。
4. TVerRecを `windows/start_tverrec.bat`で起動した場合は、`windows/stop_tverrec.bat`でTVerRecを停止できます。
    - 関連するダウンロード処理もすべて強制停止されるので注意してください。
    - ダウンロードを止めたくない場合は、tverecのウィンドウを閉じるボタンで閉じてください。
5. TVerRecを `windows/start_tverrec.bat`で実行している各ツールを個別に起動するために、`windows/a.download_video.bat` / `windows/b.delete_trash.bat` / `windows/c.validate_video.bat` / `windows/d.move_video.bat`を使うこともできます。それぞれ、動画のダウンロドード、無視した動画やダウンロード中断時のゴミファイルの削除、ダウンロードした動画の検証、検証した動画の保存先への移動を行います。(`windows/start_tverrec.bat`はこれらを自動的に、且つ無限に実行します)

個別の設定はテキストエディタで変更する必要があります。

### 動作環境の設定方法

- `config/user_setting.conf`をテキストエディターで開いてユーザ設定を行ってください。
  - `$downloadBasePath`には動画をダウンロードするフォルダを設定します
  - `$saveBasePath`にはダウンロードした動画を移動する先のフォルダを設定します
  - `$moveToParentNameList`には`$saveBasePath`配下に存在するフォルダをカンマ区切りで設定します
    - ここで設定したフォルダ配下にあるフォルダと`$downloadBasePath`にあるフォルダが一致する場合、動画ファイルが`$downloadBasePath`から`$saveBasePath`配下の各フォルダ配下に移動されます
  - `$parallelDownloadNum`は同時に並行で実行するダウンロード数を設定します
  - `$windowStyle`にはyt-dlpのウィンドウをどのように表示するかを設定します
    - `Normal` / `Maximized` / `Minimized` / `Hidden` の4つが指定可能です
  - `$forceSoftwareDecode`に`$true`を設定するとハードウェアアクセラレーションを使わなくなります
    - 高速なCPUが搭載されている場合はハードウェアアクセラレーションよりもCPUで処理したほうが早い場合があります
    - ハードウェアアクセラレーション方式の検出がうまくいかない場合(動画の検証が全く進まない場合)にも`$true`に設定してください

### ダウンロード対象のジャンルの設定方法

- `config/keyword.conf`をテキストエディターで開いてダウンロード対象のジャンルを設定します。
  - 不要なジャンルは `#` でコメントアウトしてください。
  - 主なジャンルは網羅しているつもりですが、不足があるかもしれません。

### ダウンロード対象外の番組の設定方法

- `config/ignore.conf`をテキストエディターで開いて、ダウンロードしたくない番組名を設定します。
  - ジャンル指定でダウンロードすると不要な番組もまとめてダウンロードされるので、個別にダウンロード対象外に指定できます。

## おすすめの使い方

- TVerのカテゴリ毎のページを指定して`windows/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、フォローしているタレントページを指定して`windows/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、各放送局毎のページを指定して`windows/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。

## Linux/Macでの利用方法

- `ffmpeg`と`yt-dlp`を`bin`ディレクトリに配置するか、シンボリックリンクを貼ってください。
  - または、`config/system_setting.conf`に相対パス指定で`ffmpeg`と`yt-dlp`のパスを記述してください。
- 上記説明の`windows/*.bat`は`unix/*.sh`に読み替えて実行してください。

## フォルダ構成

```text
tverrec/
├─ bin/ .................................. 実行ファイル格納用フォルダ
│
├─ config/ ............................... 設定フォルダ
│  ├─ ignore.conf .......................... ダウンロード対象外設定ファイル
│  ├─ keyword.conf ......................... ダウンロード対象ジャンル設定ファイル
│  ├─ system_setting.conf .................. システム設定ファイル
│  └─ user_setting.conf .................... ユーザ設定ファイル
│
├─ db/ ................................... データベース
│  └─ tver.csv ............................. ダウンロードリスト
│
├─ src/ .................................. 各種ソース
│  ├─ common_functions.ps1 ................. 共通関数定義
│  ├─ delete_trash.ps1 ..................... ダウンロード対象外ビデオ削除ツール
│  ├─ move_vide.ps1 ........................ ビデオを保存先に移動するツール
│  ├─ tver_functions.ps1 ................... TVer用共通関数定義
│  ├─ tverrec_bulk.ps1 ..................... 一括ダウンロードツール本体
│  ├─ tverrec_single.ps1 ................... 単体ダウンロードツール
│  ├─ update_ffmpeg.ps1 .................... ffmpeg自動更新ツール
│  ├─ update_yt-dlp.ps1 .................... yt-dlp自動更新ツール
│  └─ validate_video.ps1 ................... ダウンロード済みビデオの整合性チェックツール
│
├─ unix/ ................................. Linux/Mac用シェルスクリプト
│  ├─ a.download_video.sh .................. 一括ダウンロードシェルスクリプト
│  ├─ b.delete_video.sh .................... ダウンロード対象外ビデオ・中間ファイル削除シェルスクリプト
│  ├─ c.validate_video.sh .................. ダウンロード済みビデオの整合性チェックシェルスクリプト
│  ├─ d.move_video.sh ...................... ビデオを保存先に移動するシェルスクリプト(もし必要であれば)
│  ├─ start_tverrec.sh ..................... 無限一括ダウンロード起動シェルスクリプト
│  └─ stop_tverrec.sh ...................... 無限一括ダウンロード終了シェルスクリプト
│
├─ windows/ .............................. Windows用BATファイル
│  ├─ a.download_video.bat ................. 一括ダウンロードBAT
│  ├─ b.delete_video.bat ................... ダウンロード対象外ビデオ・中間ファイル削除BAT
│  ├─ c.validate_video.bat ................. ダウンロード済みビデオの整合性チェックBAT
│  ├─ d.move_video.bat ..................... ビデオを保存先に移動するBAT(もし必要であれば)
│  ├─ start_tverrec.bat .................... 無限一括ダウンロード起動BAT
│  └─ stop_tverrec.bat ..................... 無限一括ダウンロード終了BAT
│
├─ LICENSE .................................. ライセンス
├─ README.md ................................ このファイル
└─ TODO.md .................................. 今後の改善予定のリスト
```

## アンインストール方法

- レジストリは一切使っていないでの、不要になったらゴミ箱に捨てれば良いです。

## 注意事項

- 著作権について
  - このプログラムの著作権は dongaba が保有しています。

- 事故、故障など
  - 本ツールを使用して起こった何らかの事故、故障などの責任は負いかねますので、ご使用の際はこのことを承諾したうえでご使用ください。

## ライセンス

- TVerRecは[Apache License, Version 2.0のライセンス規約](http://www.apache.org/licenses/LICENSE-2.0)に基づき、複製や再配布、改変が許可されます。

Copyright(c) 2021 dongaba All Rights Reserved.
