NimでPNM画像を扱うライブラリを書いた
====================================

# はじめに

NimでPNM画像を扱うライブラリを書きました。
https://github.com/jiro4989/pnm

https://qiita.com/jiro4989/items/19df1f6ec0c3a147c4ac の手順を実施して
すでに`nimble install`可能な状態です。

# 環境

- Ubuntu18.10
- Nim 0.19.4

# PNMとは

[PNM - Wikipedia](https://ja.wikipedia.org/wiki/PNM_(%E7%94%BB%E5%83%8F%E3%83%95%E3%82%A9%E3%83%BC%E3%83%9E%E3%83%83%E3%83%88))に書いてある内容がわかりやすいです。
一応説明すると、2次元の数値の並びがそのまま画像として表示される画像フォーマットになります。

たとえば以下のテキストはPNMの1つです。

```1.pnm
P1
5 5
0 0 1 0 0
0 1 1 0 0
0 0 1 0 0
0 0 1 0 0
0 1 1 1 0
```

これを画像ビューワで開くと、以下のようにレンダリングされます。

![t.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/69665/cb98c152-52f6-4539-11ac-8f7165c3f3d7.png)

前述のテキストファイルは以下のような書式になっています。

- 1行目に画像フォーマット名
- 2行目に列数、行数
- 3行目以降に画像のデータ

データ部分については、0が白色、1が黒色としてレンダリングされます。
PNMはテキストファイルだけ渡されても自力で脳内レンダリングしやすいフォーマットです。

前述の P1 というディスクリプタの画像は PBM という画像フォーマットになります。
PNM(Portable Anymap)は1つの画像フォーマットではなく、PBM、PGM, PPMの総称です。

PNMの画像フォーマットはWikiにも記載あるとおり6種類あります。

| ディスクリプタ | データフォーマット |
| ---------------|--------------------|
| P1             | PBM (テキスト)     |
| P2             | PGM (テキスト)     |
| P3             | PPM (テキスト)     |
| P4             | PBM (バイナリ)     |
| P5             | PGM (バイナリ)     |
| P6             | PPM (バイナリ)     |

今回作成したpnmというライブラリでは、この6種類すべて扱えるように実装しました。

# PBMの実装

PBM、PGM、PPMと書式があって、どれも簡単なフォーマットだったので実装には苦労しませんでした。
そのうち、一番めんどくさかったのは、PBM(P4)です。

バイナリ形式なのですが、バイナリデータのビットがそれぞれ画像のドットに対応するので
0, 1の数値データを8個ずつ切り出して1byteのデータに変換する必要がありました。
この記事ではPBMの書き込みについてを取り扱います。

## ライブラリの使い方

pnmライブラリを使ってPBM P4として画像出力するコード例をいかに示します。

```nim
import pnm

let col = 5
let row = 5
let data = @[
  0'u8, 0, 1, 0, 0,
  0,    1, 1, 0, 0,
  0,    0, 1, 0, 0,
  0,    0, 1, 0, 0,
  0,    1, 1, 1, 0,
]
let pbm = newPBM(pbmFileDiscriptorP4, col, row, data.toBin(5))
writePBMFile("1.pbm", pbm)
```

このコードを実行すると、前述のPNM画像ファイルが生成されます。

## 2進数のデータをbyteデータに変換する

`data`は5行5列のデータです。
25個のデータですが、これをbyteデータに変換します。
期待値としては、以下のようなbyteデータにします。

```
0b0010_0000,
0b0110_0000,
0b0010_0000,
0b0010_0000,
0b0111_0000,
```

`newPBM(pbmFileDiscriptorP4, col, row, data.toBin(5))`
でのtoBinはbyteデータへの変換をやっています。

5データずつ切り出して5bitのデータにする必要がありますが
byteデータは8bitです。
byte型にするには3bit分たりないのですが、足りない分は左シフトします。
toBinプロシージャの実装をいかに示します。

```nim
proc toBin*(arr: openArray[uint8], col: int =  8): seq[uint8] =
  ## Returns sequences that binary sequence is converted to uint8 every 8 bits.
  runnableExamples:
    doAssert @[1'u8, 1, 1, 1, 0, 0, 0, 0].toBin == @[0b1111_0000'u8]
    doAssert @[1'u8, 1, 1, 1, 1, 1].toBin == @[0b1111_1100'u8]
    var s: seq[uint8]
    doAssert s.toBin == s
  var data: uint8
  var i = 0
  for u in arr:
    data = data shl 1
    data += u
    i.inc
    if i mod 8 == 0:
      result.add data
      data = 0'u8
      continue
    if i mod col == 0:
      data = data shl (8 - (i mod 8))
      result.add data
      data = 0'u8
      i = 0
  if data != 0:
    result.add data shl (8 - (i mod 8))
```

`arr`から1つずつデータを取り出して加算して左シフトを繰り返し、
1byte分データが加算されたら`result`に追加を繰り返すような実装です。

Nimでは`##`をプロシージャ内に書くとドキュメンテーションコメントとして扱われます。
ライブラリとして公開するためにドキュメントも必要と思ったので書いています。

`runnableExamples`もドキュメンテーションコメントの1つです。
`nim doc`でドキュメントを生成する際に、runnableExamplesのブロックのコードを実際にコンパイルして実行して
コードが実行可能であることを検証してくれます。また、このブロックにかかれているコードもドキュメントに含まれます。

このソースコードから以下のドキュメントが生成されます。
https://jiro4989.github.io/pnm/util.html#toBin%2CopenArray%5Buint8%5D%2Cint

## ファイル出力

`writePBMFile`では`newPBM()`で生成した構造体をbyteデータに変換してファイル出力します。
byteデータへの変換は以下のような実装になっています。
データ構造は単純で、それぞれのデータを`uint8`型に変換しているだけです。

```nim
proc formatP4*(self: PBM): seq[uint8] =
  ## Return formatted byte data for PBM P4.
  runnableExamples:
    let p4 = newPBM(pbmFileDiscriptorP4, 1, 1, @[0b1000_0000'u8])
    doAssert p4.formatP4 == @[
      'P'.uint8, '4'.uint8, '\n'.uint8,
      '1'.uint8, ' '.uint8, '1'.uint8, '\n'.uint8,
      0b10000000'u8,
    ]
  # header part
  # -----------
  # file discriptor
  result.add self.fileDiscriptor.mapIt(it.uint8)
  result.add '\n'.uint8
  # col and row
  result.add self.col.`$`.mapIt(it.uint8)
  result.add ' '.uint8
  result.add self.row.`$`.mapIt(it.uint8)
  result.add '\n'.uint8
  # data part
  # ---------
  result.add self.data
```

書き込みをしている箇所はこれだけ。特に凝ったことはしていません。

```
let bin = data.formatP4
discard f.writeBytes(bin, 0, bin.len)
```

# まとめ

PNMを扱うためのライブラリの使い方と、その実装の一部について説明しました。

PNMはPNGなどの一般的な画像フォーマットと比べると、非常に簡単な書式なので、実装の練習としては有用です。
僕の場合は、ビット演算を今までほとんどやったことなかったのですが、PBM
P4の実装を通してビット演算の理解が深まりました。

あと実装についてですが、メソッドチェーンで処理をどんどんつないで
コードをかけるのが面白いな、と感じました。

特に`sequtils`と`strutils`のモジュールには強力なものがたくさんあるので
少ないコード量でスイスイ実装を進められたと感じています。
また、スライスの値比較とかも普通に`==`でできますし、構造体のポインタ型のデータの値比較も
変数名の後に`[]`と書くだけで値型として扱えるのでテストコードも書きやすいです。

コード量はテストコード込で以下のようになりました。

```
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Nim                              4            105            402           1075
-------------------------------------------------------------------------------
TOTAL                            4            105            402           1075
-------------------------------------------------------------------------------
```

しかしながら、後からコードを見直したときに、１行の情報量が増えやすく
気を抜くとすぐに可読性が低下しそうな危うさも感じました。
普段良く使ってるGoと比べると可読性は低くなりやすいと感じます。

