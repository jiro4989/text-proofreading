Terminal上の色のついたテキストを画像に再現するコマンド(textimg)をGoで作った
===========================================================================

Terminal上の色のついたテキストを画像に再現するtextimgというコマンドをGoで作りました。
なぜ作ったのか、と何ができるのか、について記載します。

リポジトリは下記。

https://github.com/jiro4989/textimg

[:contents]

# なぜ作ったのか

[シェル芸bot](https://twitter.com/minyoruminyon)環境で色付きのテキストを画像に再現したかったからです。
シェル芸bot環境にはImageMagickがインストールされています。
また、テキストを画像に出力する処理を簡易にするための[imgout](https://github.com/ryuichiueda/ImageGeneratorForShBot/blob/master/imgout)というコマンドもあります。

ImageMagickで色のついたテキストを画像に変換するには、非常に複雑な
オプションを組み合わせる必要があって、Twitterの文字数内では辛いものがあります。

Linux環境でテキストに色をつけるにはエスケープシーケンスを使用します。
色のついたテキストを出力するコマンドもいくつかあって
それをそのまま画像に起こせたら楽しいかな、と考えたからです。

# 使い方

非常に単純な使用例は下記のとおりです。

```bash
textimg $'\x1b[31mRED\x1b[0m' -o out.png
```

TODOここに画像。

より複雑な使用例は下記のとおりです。

```bash
seq 0 255 | while read -r i; do
  echo -ne "\x1b[48;5;${i}m$(printf %03d $i)"
  if [ $(((i+1) % 16)) -eq 0 ]; then
    echo
  fi
done | textimg -o 256_bg.png
```

TODOここに画像。

アニメーションGIFにも対応しています。
シェル芸bot環境での使用例は以下です。

https://twitter.com/minyoruminyon/status/1128270441087262720

使用しているコマンドのオプションの説明は以下のとおりです。

`textimg -sal8 -d 6 -F 4`

- `-s` シェル芸botの画像出力先ディレクトリに画像を保存する(/images/t.gif)
- `-a` アニメーションGIFとして画像を生成する
- `-l 8` 1フレームの画像に何行テキストを使用するか
- `-d 6` アニメーションのフレームの待ちフレーム(delay)
- `-F 4` フォントサイズ

# 実装

エスケープシーケンスを含む文字列は以下のように分解・分類できる。

`\x1b[1;31;42mRed foreground Green background\x[0mNormal`

- 分解後
  - `\x1b[1;31;42m`
    - 1 太字にする (文字装飾）
    - 31 文字色を赤にする （色変更）
    - 42 背景色を緑にする（色変更）
  - Red foreground Green background (文字列)
  - `\x1b[0m` 文字の装飾や色変更をもとに戻す (色変更)
  - Normal (文字列)

このように文字列をエスケープシーケンスか、テキストかに分解し、
エスケープシーケンスの中から着色に関係のある文字列か否かに分類している。

エスケープシーケンスとのマッチはそれぞれ以下の[正規表現]で取り出している。

- 色系：`^\x1b\[[\d;]*m`
- 色系以外：`^\x1b\[\d*[A-HfSTJK]`

画像描画では、文字列が来たときだけ画像変数にテキストを書き込み、それ以外の場合
は書き込むテキストに指定する色や装飾の変更だけを行うのをひたすら繰り返すように
している。

前述の文字列の場合は以下のような順序で処理をしています。

1. なにもしない(太字装飾は無視)
1. `foregroundColor = red`
1. `backgroundColor = green`
1. `drawText("Red foreground Green background", foregroundColor, backgroundColor)`
1. `foregroundColor = defaultColor`
1. `backgroundColor = defaultColor`
1. `drawText("Normal", foregroundColor, backgroundColor)`

※実装のイメージなので実際のコードの通りではないです(変数名とか)。

エスケープシーケンスなどの情報は[Bash tips: Colors and formatting (ANSI/VT100 Control sequences)](https://misc.flogisoft.com/bash/tip_colors_and_formatting)を参考にした。

# まとめ

Terminal上の色のついたテキストを画像に再現するtextimgというコマンドについて
説明しました。

シェル芸bot環境に色のついたテキストを画像として再現できるようになって
とても満足しています。

それなりにシェル芸botを使ってる方からも気に入っていただけたようで、
作って公開して少ししか経っていないのにスター数が一番多いリポジトリになりました。
やはりそれなりに需要のあるものだったんですね。

ひとまずPNG生成できるようになって、アニメーションGIFも作れるようになって
ひとまず自分のほしかった機能はだいたい実装し終わりました。
アップデートは何かバグが見つかったときとか、PRが来た時だけを考えています。

以上です。
