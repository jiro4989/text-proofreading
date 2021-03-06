Nim 0.20は事実上Nim 1.0のRC版らしいのでNimでテストコードを書く
==============================================================

Nimのバージョン0.20がリリースされました。
これはNim1.0の事実上RC版らしいです。Nim 1.0のリリースの日が近い、ということです。

https://nim-lang.org/blog/2019/06/06/version-0200-released.html

それは置いといてNimでテストコードを書くことについて整理しました。

# 検証環境

nim 0.19.6

なぜ0.19かというと`choosenim`で0.20.0にしたらnimは動きましたが、nimbleが動かなかったからです・・・。

# assert系でテストする

## assertとdoAssert

Nimでは値比較をして不正な場合は例外を返す`assert`系のプロシージャやテンプレートがいくつかあります。
そのうちよく使うのは`assert`と`doAssert`です。

https://nim-lang.github.io/Nim/assertions.html#doAssertRaises.t%2Ctypedesc%2Cuntyped

ではassertとdoAssertどちらを使うべきか、ですがdoAssertを使いましょう。

assertとdoAssertの違いですが、assertはコンパイル時にオプションを与えることでassertでのチェックを無視します。
doAssertはオプションを与えてもassertでのチェックを継続します。

```a.nim
assert(false, "assertで失敗した")
doAssert(false, "doAssertで失敗した")
```

```bash
$ nim c -r a.nim
...省略...
Error: unhandled exception: /tmp/a.nim(1, 7) `false` assertで失敗した [AssertionError]

$ nim c --assertions:off -r a.nim
...省略...
Error: unhandled exception: /tmp/a.nim(2, 9) `false` doAssertで失敗した [AssertionError]
```

ですが、これだけでテストコードを書くのは得策ではありません。
なぜかというとassertのみだとテストを通過してもOK/NGなどのメッセージが出力されないからです。
他にもunittestからテストするときのことを考えるとあまり使うべきではありません（後述）。

# unittestでテストする

多くの場合はこちらでテストコードを書きます。

## テストをするためのプロジェクト構造

`nimble init`でプロジェクトを作成したとき、自動で`tests`というディレクトリが生成されます。
testsディレクトリ配下に`t`で始まるnim拡張子のファイルが存在すれば、`nimble test`を実行したときに
テストコードとして実行される。

```
project/
+- tests/
|  `- test1.nim
`- project.nimble
```

### バイナリファイルをgitの監視対象から除外

`nimble test`を実行するとバイナリファイルがtestsディレクトリ配下に生成されます。
たとえば`tmain.nim`というファイルが存在したとき`tmain`というバイナリファイルがtestsディレクトリ配下に生成されます。
これはgitで管理したくないので、以下のようなgitignoreを追加します。

Windowsだと多分exeファイルを除外します。
(WindowsPCを持っていない)

```.gitignore
tests/*
!tests/*.*

# Windowsだとこう？
tests/*.exe
```

## 非公開プロシージャのテストとimport/include

例えば`src/main.nim`をテストしたいとき、`tests/tmain.nim`内に以下のようにしてモジュールを読み込むことになります。

```nim
import main

# あるいは

include main
```

どちらを使うべきか、ですが非公開のプロシージャのテストをしたい場合は`include`のほうを使う必要があります。
`import`では非公開プロシージャにアクセスできないためです。

しかしながら、`include`を使う場合も問題があります。
`include`を使うと、読み込んだモジュールの`when isMainModule`ブロックも読み込まれてしまい、
テスト時に実行されてしまうためです。

```src/project.nim 
proc add(x, y: int): int =
  return x + y

when isMainModule:
  echo "Main Module"
  quit 0
```

```tests/test1.nim 
import unittest

include project

suite "add":
  test "1 + 1 == 2":
    check add(1, 1) == 2
  test "0 + 1 == 1":
    check add(0, 1) == 1
  test "-1 + 1 == 0":
    check add(-1, 1) == 0
  test "0 + 0 == 0":
    check add(0, 0) == 0
```

```bash
% nimble test
  Executing task test in /tmp/project/project.nimble
  Verifying dependencies for project@0.1.0
  Compiling /tmp/project/tests/test1.nim (from package project) using c backend
CC: project_test1
Main Module
   Success: Execution finished
   Success: All tests passed
```

これは実行可能ファイルを作る目的のmain処理を書いているモジュールをテストする時問題になります。
`when isMainModule`のブロックの途中や最後に`quit`処理を入れていた場合に、
後続のテストコードが実行されなくなってしまいます。

なので、`include`を使ってテストをする前提のモジュールで`when isMainModule`を書くときは
テストコードから読み込まれても問題ないように実装する必要があります。

## suite/testでテストの目的を表現する

テストの粒度をどれくらいにするかはケースバイケースです。
僕が一番やるのはプロシージャ単位でsuiteを使用します。

```nim
suite "プロシージャ名":
  test "テストの目的、期待値の説明":
    check procedure1() == expect
```

引数を書き換えるプロシージャのテストを行う場合は`setup`で変数を宣言すると便利です。
`setup`は`test`が実行される直前に都度実行されます。

```nim
proc add1(n: var int) =
  n.inc
```

```tests/test1.nim
suite "add1":
  setup:
    echo "setup"
    var n = 1
  test "test1":
    n.add1()
    check n == 2
  test "test2":
    n.add1()
    check n == 2
  test "test3":
    n.add1()
    check n == 2
```

```bash
% nimble test
  Executing task test in /tmp/project/project.nimble
  Verifying dependencies for project@0.1.0
  Compiling /tmp/project/tests/test1.nim (from package project) using c backend
CC: project_test1
[Suite] add1
setup
  [OK] test1
setup
  [OK] test2
setup
  [OK] test3
   Success: Execution finished
   Success: All tests passed
```

## expectで例外をテストする

例外が返ることをテストするときは`expect`を使います。

配列、シーケンスの先頭の要素を返す`first`というプロシージャをテストする例を示します。

```nim
proc first(n: openArray[int]): int =
  return n[0]
```

このプロシージャでは配列が空の配列だとエラーが発生します。
このときに、例外が返ることを`expect`を使用して以下のようにテストします。

```nim
suite "first":
  test "1 2 3 == 1":
    check first([1, 2, 3]) == 1
  test "empty data -> IndexError":
    var empty: seq[int]
    expect IndexError:
      discard first(empty)
```

```bash
% nimble test
  Executing task test in /tmp/project/project.nimble
  Verifying dependencies for project@0.1.0
  Compiling /tmp/project/tests/test1.nim (from package project) using c backend
[Suite] first
  [OK] 1 2 3 == 1
  [OK] empty data -> IndexError
   Success: Execution finished
   Success: All tests passed
```

# runnableExamplesでテストする

これはテストコードを書くためのメインに使うものではないですが、
ドキュメントを書くためには非常に便利です。

Nimでドキュメンテーションコメントを書くときに
runnableExamplesを書くと、書いたサンプルコードが実際に動作することを検証できます。

これは標準ライブラリでは、プロシージャごとのドキュメンテーションコメントを書く際に使用されていますが、
これはモジュールのトップレベルのドキュメントを書く際にも使用できます。

しかしながら、runnableExamplesで生成されるドキュメントからは
空白行やインデント、コメントが削除されてしまうので、
みやすさを確保したドキュメントを整備したいときには使用できません。
また、コメントを一緒に描画したい場合は`##`でコメントを書かないと消されてしまいます。

```nim
## project はNimのドキュメント生成の練習用のモジュールです。
##
## code-blockで表現する例
## ----------------------
##
## .. code-block:: nim
##
##    import project
##
##    # sum のテスト
##    ## sum のテスト2
##    doAssert sum(@[@[1, 2, 3],
##                   @[4, 5, 6],
##                   @[7, 8, 9]]) == 45
##
## runnableExamplesで表現する例
## ----------------------------
##

runnableExamples:
  import project

  # sum のテスト
  ## sum のテスト2
  doAssert sum(@[@[1, 2, 3],
                 @[4, 5, 6],
                 @[7, 8, 9]]) == 45

import sequtils

proc sum*(n: seq[seq[int]]): int =
  return n.mapIt(it.foldl(a+b)).foldl(a+b)

when isMainModule:
  echo sum(@[@[1, 2], @[3, 4]])
```

このコードから`nim doc`で以下のドキュメントが生成されます。

TODO

runnableExamplesで、コンパイルして実行して正常終了しないコードが存在した場合は
`nim doc`のときに異常終了します。

# テストを書くためのTIPS

## 参照型のテスト

Nimでは嬉しいことに配列やシーケンス、構造体の値比較が`==`で行えます。
参照型の値比較は`==`では行えないのですが、これも容易に回避する方法があります。
`[]`というプロシージャを使用することで参照型の値の取得が可能です。
これを利用して参照型の値比較も容易に行えます。

https://nim-lang.org/docs/tut1.html#advanced-types-reference-and-pointer-types

一部を抜粋して和訳。

> 空の[]添え字表記は、参照を延期するために使用できます。つまり、参照が指す項目
> を取得するという意味です。

```nim
type
  Obj = object
    n: int
  RefObj = ref object
    n: int

echo "Obj:      ", Obj(n: 1) == Obj(n: 1)
echo "RefObj:   ", RefObj(n: 1) == RefObj(n: 1)
echo "RefObj[]: ", RefObj(n: 1)[] == RefObj(n: 1)[]
echo "Array:    ", [1, 2, 3] == [1, 2, 3]
echo "Seq:      ", @[1, 2, 3] == @[1, 2, 3]
```

```bash
% nim c -r b.nim
Obj:      true
RefObj:   false
RefObj[]: true
Array:    true
Seq:      true
```

# まとめ

自分でライブラリを書いたり、[Nimの標準ライブラリのドキュメント整備](https://github.com/nim-lang/Nim/issues/10330)に関わったりした際に
色々ハマって解決したときの情報を整理しました。
