NimでEastAsianWidthを扱うためのライブラリを作った
=================================================

NimでEastAsianWidthを扱うためのライブラリを作りました。
なぜ作ったのか、と何ができるのか、について記載します。

[:contents]

# EastAsianWidthとは

[東アジアの文字幅の問題 - Wikipedia](https://ja.wikipedia.org/wiki/%E6%9D%B1%E3%82%A2%E3%82%B8%E3%82%A2%E3%81%AE%E6%96%87%E5%AD%97%E5%B9%85)という名称で知られている
文字幅についてのヒントのことです。

いわゆる半角文字は半角1文字分、全角文字は半角2文字分の幅になるということを定義化したものです。
その他にも文字の分類について定義しています。

# なぜ作ったのか

CLIツールを作る上で全角文字の幅を考慮した実装の必要があったためです。
Goだとサードパーティのライブラリで[go-runewidth](https://github.com/mattn/go-runewidth)がそれを実現できるのですが
Nimにはこれに相当するものがありませんでした。

なので、Node.js用のライブラリ[eastasianwidth](https://github.com/komagata/eastasianwidth)を参考に
Nimにも実装してみた次第です。

# 何が問題になるのか

例えばプログラムでテキストを使用して罫線などを表現するケースを考えます。
テーブルを表現する罫線を引き、セル内にテキストを書くとき、
文字幅を考慮しないでプログラムから扱おうとすると罫線の位置がずれてしまいます。

問題になるケースの実装を示します。

```nim
from eastasianwidth import stringWidth
from sequtils import mapIt
from strutils import repeat
from unicode import runeLen

let texts = ["test code", "テストコード"]

echo """
string.len pattern
------------------
"""

# 文字の長さ(byteサイズ)のみで実装
let maxByteLen = texts.mapIt(it.len).max
for text in texts:
  let diff = maxByteLen - text.len
  let pad = " ".repeat(diff)
  echo "| " & text & pad & " |"

echo """

string.runeLen pattern
----------------------
"""

# rune文字の長さでの実装
let maxRuneLen = texts.mapIt(it.runeLen).max
for text in texts:
  let diff = maxRuneLen - text.runeLen
  let pad = " ".repeat(diff)
  echo "| " & text & pad & " |"

echo """

string.stringWidth pattern
----------------------
"""

# eastasianwidthを使用した、表示上の幅を考慮した実装
let maxStringWidth = texts.mapIt(it.stringWidth).max
for text in texts:
  let diff = maxStringWidth - text.stringWidth
  let pad = " ".repeat(diff)
  echo "| " & text & pad & " |"
```

このコードを実行したときの結果は以下のとおりです。

<figure class="figure-image figure-image-fotolife" title="実行結果">[f:id:jiroron666:20190525065525p:plain]<figcaption>実行結果</figcaption></figure>

## 絵文字の例

絵文字は少し特殊です。
EastAsianWidthでは絵文字はNeutralに属しており、1文字分として扱われます。

しかしながら、ほとんどのソフトは絵文字を2文字分として扱っています。
なので、絵文字はNeutralであるけれど、文字幅としては2文字を返すようにする必要がありました。
絵文字コード範囲だけ特別扱いするようにして、2文字幅を返すように実装しました。

以下に文字幅のテストコードを転記します。

```nim
import eastasianwidth

doAssert "☀☁☂☃".stringWidth == 8
doAssert "🧀".stringWidth == 2
```

# ライブラリの使い方

## インストール

インストールには以下のコマンドを実行します。

```bash
nimble install eastasianwidth
```

プロジェクトとして使用する場合は、
Nimbleファイルに記述する以下の設定を記述します。

```nimble
requires "eastasianwidth >= 1.1.0"
```

使い方は前述の問題になる例を参考にしてください。

また、[rect](https://github.com/jiro4989/rect)というツールで
実際に僕は今回作成したeastasianwidthライブラリを使用しています。
このrectについてはいずれ記事にしようと思います。

# まとめ

自作のライブラリ`eastasianwidth`について説明しました。

仕組みは結構単純なので実装にはそこまで苦労しませんでした。
他の言語に移植するのも容易だと思います。

今後別言語で同様の問題に遭遇したときは移植しようかなぁと思います。

