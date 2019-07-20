# Nimの実行可能バイナリをTravisとAppVeyorでクロスプラットフォーム向けに生成してリリースする

高速に動作する実行可能バイナリを生成できるといわれているNimなので
クロスプラットフォーム向けにバイナリを生成して、コマンドを配布したいと考えました。

ここではTravisCIとAppVeyorを利用して、
Nimのコードから各プラットフォーム向けのバイナリを生成できるようにするまでの手順を書きます。

## travisコマンドのインストール

TravisからGitHub Releasesへリリースするトークン取得のために`travis`コマンドのインストールします。

LinuxMintにデフォルトで入ってるRubyだとtravisのインストールで失敗しました。
ruby-devが必要だったのでインストールします。

```bash
sudo apt update -y
sudo apt install -y ruby-dev
sudo apt install -y build-essential
sudo gem install travis
```

リリースしたいリポジトリで.travis.ymlを生成し、`travis`コマンドを実行します。

```bash
touch .travis.yml
travis setup releases --org -r jiro4989/nim-release-sample
```

以下のようなYAMLファイルが生成されます。

```.travis.yml
deploy:
  provider: releases
  api_key:
    secure: 省略
  file: ''
  on:
    repo: jiro4989/nim-release-sample # ここはリポジトリによってかわる
```

## GitHubReleasesへアップするTravisのタスクを書く

.travis.ymlの設定を変更してLinuxとMacOS向けのバイナリを生成するタスクを書きます。
書いたものが以下。`language`でNim用のものが存在しないので、公式の.travis.ymlを参考に`language c`としました。

```.travis.yml
sudo: false

language: c

os:
  - linux
  - osx

env:
  - PATH=$HOME/.nimble/bin:$PATH
    APP_NAME=ここにパッケージ名

cache:
  directories:
    - $HOME/.nimble
    - $HOME/.choosenim

addons:
  apt:
    packages:
      - libcurl4-openssl-dev
      - libsdl1.2-dev
      - libgc-dev
      - libsfml-dev

before_install:
  - if [ ! -e $HOME/.nimble/bin/nim ]; then curl https://nim-lang.org/choosenim/init.sh -sSf -o init.sh && bash init.sh -y; fi

before_script:
  - set -e
  - if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then unset -f cd; fi
  - echo PATH:${PATH}
  - set +e

script:
  - set -e
  - nimble ci
  - set +e

before_deploy:
  - mkdir -p dist/${APP_NAME}_${TRAVIS_OS_NAME}
  - cp -rf LICENSE README* bin dist/${APP_NAME}_${TRAVIS_OS_NAME}/
  - tar -C dist -czf ${APP_NAME}_${TRAVIS_OS_NAME}{.tar.gz,}

deploy:
  provider: releases
  api_key:
    secure: 省略
  keep-history: false
  skip_cleanup: true
  file: ${APP_NAME}_${TRAVIS_OS_NAME}.tar.gz
  on:
    tags: true
```

`before_install`でchoosenimをインストールしています。
choosenimでのnimのインストールは10分以上かかります。
Travisで毎回コンパイラをインストールしていると時間がかかるのでキャッシュするようにしています。

`script`では`nimble ci`を実行しています。
これは独自に定義したnimbleのタスクです。
以下がタスクを定義しているそのnimbleファイルです。
[nimjson](https://github.com/jiro4989/nimjson)という自作のコマンドのnimbleファイルです。

```nimjson.nimble
# Package

version       = "1.2.1"
author        = "jiro4989"
description   = "nimjson generates nim object definitions from json documents."
license       = "MIT"
srcDir        = "src"
bin           = @["nimjson"]
binDir        = "bin"
installExt    = @["nim"]

# Dependencies

requires "nim >= 0.20.0"

task docs, "Generate documents":
  exec "nimble doc src/nimjson.nim -o:docs/nimjson.html"

task examples, "Run examples":
  for dir in ["readfile", "mapping"]:
    withDir "examples/" & dir:
      exec "nim c -d:release main.nim"
      exec "./main"

task buildjs, "Generate JS lib":
  exec "nimble js js/nimjson_js.nim -o:docs/js/nimjson.js"

task ci, "Run CI":
  exec "nim -v"
  exec "nimble -v"
  exec "nimble install -Y"
  exec "nimble test -Y"
  exec "nimble docs -Y"
  exec "nimble build -d:release -Y"
  exec "nimble examples"
  exec "nimble buildjs"
  exec "./bin/nimjson -h"
  exec "./bin/nimjson -v"
```

`task ci, "Run CI"`ではTravisCIにやらせたい諸々のタスクを全て定義しています。
`nimble docs`、`nimble examples`、`nimble buildjs`も独自に定義したタスクです。

わざわざnimbleファイルにタスクを定義するのが面倒な場合は、
.tavis.ymlに書くのは以下のscriptタスクで十分です。

```.travis.yml
script:
  - set -e
  - nim -v
  - nimble -v
  - nimble install -Y
  - nimble test -Y
  - nimble build -d:release -Y
  - set +e
```

`before_deploy`では`nimble build -d:release`で生成したファイルとLICENSE、READMEをバイナリを圧縮しています。

これでタグを切ったタイミングでLinuxとMacOS向けのバイナリがリリースされます。

## GitHubReleasesへアップするAppVeyorのタスクを書く

Windows向けバイナリを生成するためにAppVeyorを利用します。

まず、`deploy`に必要なトークンを生成します。
[GitHub「Personal access tokens」の設定方法](https://qiita.com/kz800/items/497ec70bff3e555dacd0)などを参考にGitHubへのアクセストークンを生成します。
生成されたトークンをメモしたら、AppVeyor側の設定に移ります。

AppVeyorの設定画面の「Deployment」を表示して
Add Deploymentします。

表示されたら GitHub Releases を選択して、「GitHub authentication token」に先程メモしたトークンを追加します。
Saveしたら、サイドバーの「Export YAML」をクリックします。
すると無事`auth_token`のセットされたYAMLファイルが生成されます。

生成されたYAMLを一旦リポジトリにpushしたら、
今度はnimのコードをビルドするタスクを書きます。

以下がそのappveyor.ymlです。
こちらも前述のnimjsonのリポジトリで使用している設定です。
ベースはNim公式リポジトリのappveyor.ymlです。

```appveyor.yml
version: '{build}'

environment:
  APP_NAME: ここにパッケージ名を入力
  MINGW_DIR: mingw64
  MINGW_URL: https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/4.9.2/threads-win32/seh/x86_64-4.9.2-release-win32-seh-rt_v4-rev4.7z/download
  MINGW_ARCHIVE: x86_64-4.9.2-release-win32-seh-rt_v4-rev4.7z
  NIM_DIR: nim-0.20.0
  NIM_URL: https://nim-lang.org/download/nim-0.20.0_x64.zip
  NIM_ARCHIVE: nim-0.20.0_x64.zip
  platform: x64

cache:
    - '%MINGW_ARCHIVE%'
    - '%NIM_ARCHIVE%'

matrix:
  fast_finish: true

install:
  - MKDIR %CD%\DIST
  - IF not exist "%MINGW_ARCHIVE%" appveyor DownloadFile "%MINGW_URL%" -FileName "%MINGW_ARCHIVE%"
  - 7z x -y "%MINGW_ARCHIVE%" -o"%CD%\DIST"> nul
  - IF not exist "%NIM_ARCHIVE%" appveyor DownloadFile "%NIM_URL%" -FileName "%NIM_ARCHIVE%"
  - 7z x -y "%NIM_ARCHIVE%" -o"%CD%\DIST"> nul
  - SET PATH=%CD%\DIST\%NIM_DIR%\BIN;%CD%\DIST\%MINGW_DIR%\BIN;%CD%\BIN;%PATH%

build: off

build_script:
  - nimble ci
  - mkdir %APP_NAME%_windows
  - xcopy bin %APP_NAME%_windows\bin\
  - copy README.md %APP_NAME%_windows\
  - copy LICENSE %APP_NAME%_windows\
  - 7z a %APP_NAME%_windows.zip %APP_NAME%_windows

artifacts:
  - path: '*_windows.zip'
    name: zip

deploy:
- provider: GitHub
  auth_token:
    secure: 省略
  artifacts: zip
  on:
    branch: master
    appveyor_repo_tag: true 
```

欠点ですが、Nimのバージョンを変数でベタ打ちしているので、最新版に追従できません。
なんとかこの問題も解決したいと考えていますが、現状良い方法が思いつかないです。

## 動作確認

GitHubのリポジトリを開いてReleasesを表示します。
「Draft a new release」のボタンをクリックして、諸々テキストを入力して
タグを追加してみます。

タグを追加するとTravisCIとAppVeyorのタスクが走り初めますので完了するのを待ちます。

完了したらReleasesに各プラットフォーム向けのバイナリを含んだ圧縮ファイルが配置されます。


## まとめ

TravisCIとAppVeyorを利用してNimのコードから各プラットフォーム向けのバイナリを生成するフローと設定について説明しました。

NimはGoのようにコマンド単体で各プラットフォーム向けのバイナリを生成できません。
設定ファイルやmingwの準備などが必要で、環境を整えるのがとても大変です。

この問題をTravisCIとAppVeyorを利用して実現しました。
どちらも無料で利用可能なサービスですので、すぐに試すことができます。
僕もとても助かっています。ありがたやありがたや・・・。

せっかく高速に動作するバイナリが作れると言われているNimなので
Rustでいう[bats](https://github.com/sharkdp/bat)、
Goでいう[peco](https://github.com/peco/peco)のように
Nimでももっとコマンド作成する流れが生まれてほしいなぁと思っています。

参考までに、TravisCIとAppVeyorを利用して
各プラットフォーム向けにバイナリを生成して配布しているプロジェクトを記載します。
[GitHub - jiro4989/nimjson ](https://github.com/jiro4989/nimjson)

以上です。
