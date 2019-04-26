Nimで文字コード変換
===================

# はじめに

Nimで文字コード変換を変換する方法を記載します。
内容自体はメモレベルです。

# シンプルに文字コードを変換する

Linux環境では単純にCP932のファイルを読み取ると文字化けします。

```nim
echo readFile("cp932.txt")
```

単純に`echo`しても文字化けしてしまい、端末から文字を読み取れません。

UTF-8以外のデータを読み取ったときは標準モジュールの[encodings](https://nim-lang.org/docs/encodings.html)モジュールを使用して文字コードをUTF-8に変換します。

```nim
import encodings

# 文字化けする
echo readFile("cp932.txt")

# 文字化けしない
echo readFile("cp932.txt").`$`.convert(srcEncoding="CP932", destEncoding="UTF-8")
```

これで端末上の出力でも文字化けしていないことが確認できます。

ファイルに書き込む場合は、このまま書き込んでしまえば良いです。

```nim
import encodings

var utf8data = readFile("cp932.txt").`$`.convert(srcEncoding="CP932", destEncoding="UTF-8")
writeFile("utf-8.txt", utf8data)
```

これでファイルもUTF-8として書き込まれます。

# 巨大ファイルを扱う

単純に`readFile`で開いてエンコードする場合だと
ファイルサイズが巨大だった場合に処理しきれない可能性が有ります。
その時は`streams`モジュールを使います。

```nim
import encodings, streams

var
  conv = encodings.open(srcEncoding="CP932", destEncoding="UTF-8")
  strm = newFileStream("cp932.txt", fmRead)
  outStrm = newFileStream("utf-8.txt", fmWrite)
  line: string

while strm.readLine(line):
  outStrm.writeLine conv.convert(line)

outStrm.close
strm.close
conv.close
```

これで1行ずつテキストを読み取り、都度文字コードを変換してファイル書き込みできるようになりました。

しかしながら、1行あたりのテキスト量が少なくて
行数が非常に多いような巨大ファイルの場合にめちゃくちゃ時間がかかってしまいます。
（この記事を書くにあたって、そのようなダミーデータを作成してしまい速度がでない問題に直面しました）

その場合は下記のように別の`readStr`など別のプロシージャを使うことで速度を改善できる場合が有ります。
**ただしその方法には問題が有ります（後述）**
readFile、readLine、readStrの処理速度を比較するコードを用意しました。

```nim
import encodings, streams, times
from strformat import `&`

# 巨大ファイルをreadFileで読み取る例
block:
  let
    startTime = cpuTime()
    utf8data = readFile("cp932big.txt").`$`.convert(srcEncoding="CP932", destEncoding="UTF-8")
  writeFile("utf-8big.txt", utf8data)

  echo &"system readFile example: {cpuTime()-startTime} sec"

# 巨大ファイルをreadLineで読み取る例
block:
  let
    startTime = cpuTime()
  var
    conv = encodings.open(srcEncoding="CP932", destEncoding="UTF-8")
    strm = newFileStream("cp932big.txt", fmRead)
    outStrm = newFileStream("utf-8big.txt", fmWrite)
    line: string

  while strm.readLine(line):
    outStrm.writeLine conv.convert(line)

  outStrm.close
  strm.close
  conv.close

  echo &"streams readLine example: {cpuTime()-startTime} sec"

# 巨大ファイルをreadStrで読み取る例
block:
  let
    startTime = cpuTime()
  var
    conv = encodings.open(srcEncoding="CP932", destEncoding="UTF-8")
    strm = newFileStream("cp932big.txt", fmRead)
    outStrm = newFileStream("utf-8big.txt", fmWrite)

  while true:
    let line = strm.readStr(1024)
    if line == "":
      break
    outStrm.writeLine conv.convert(line)

  outStrm.close
  strm.close
  conv.close

  echo &"streams readStr example: {cpuTime()-startTime} sec"
```

用意したダミーデータの情報は下記の通り。
500MB、700万行のテキストファイルです。

```bash
% file cp932big.txt
cp932big.txt: Non-ISO extended-ASCII text

% ls -lah cp932big.txt
-rw-rw-r-- 1 jiro4989 jiro4989 528M  4月 26 21:03 cp932big.txt

% wc -l cp932big.txt
7686144 cp932big.txt
```

このデータを食わせた実行結果は下記のとおりです。

> system readFile example: 4.040268 sec
> streams readLine example: 97.944166 sec
> streams readStr example: 5.505938 sec

readLineが非常に遅いですがreadStrは早いです。
じゃあreadStrを使えばよいのか、というとそうは問屋が降ろさない。

CP932文字コードで問題になる日本語などのマルチバイト文字を扱うさいに
readStrの引数に指定するlengthはバイトサイズでの指定になっています。

すると、マルチバイト文字の途中までしかreadStrできていないまま
文字コードの変換にかけてしまい、不正な文字になってしまうことがあります。

以下は前述の比較コードで生成されたUTF-8のテキストファイルの一部分です。
文字が途中で分断されていることがわかります。

```
% less utf-8big.txt
... 省略 ...

abcdefgああああああああああああああああああああああああああああああああ
abcdefgああああああああああああ<82>
<A0>あああああああああああああああああああ
```

データ構造的に速度が遅くても、あきらめてreadLineを使うのが無難です。
他に良い方法がアレば教えてください。

# まとめ

- 文字コードを変換する方法を学んだ
- 巨大ファイルを扱う方法を学んだ

Nimユーザのお役に立てば幸いです。
