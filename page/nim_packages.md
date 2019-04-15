# はじめに

Nimのpackagesリポジトリにライブラリを追加してみたので、
追加するまでの流れとかを記載しています。
Nimのパッケージがこれからどんどん増えるといいなぁという思いで書きました。

Nimのこと知らないよ、という方は以下の記事を参照すると幸せになると思います。
[至高の言語、Nimを始めるエンジニアへ](https://qiita.com/rigani/items/6e87c7cee6903ed65ed2)

# この記事のゴール

Nimのpackagesリポジトリへの自作パッケージ追加の流れを知る

# Nimのパッケージについて

Nimのpackagesリポジトリとは`nimble install`でインストールできるパッケージを管理しているリポジトリを指します。
JavaでいうMavenRepositoryと同じと考えていいと思います。

NimのpackagesリポジトリはGitHub上で管理されています。
https://github.com/nim-lang/packages

また、ここに登録されているパッケージは、以下のサイトにて検索できます。
https://nimble.directory/

packagesリポジトリにパッケージが登録されると`nimble install`コマンドで
ローカルにパッケージをインストールできるようになります。

# 追加したパッケージ

[eastasianwidth](https://github.com/jiro4989/eastasianwidth)というパッケージです。
READMEにも書いていますが、元はNode.jsの[eastasianwidth](https://github.com/komagata/eastasianwidth)モジュールを参考にしています。

どういうときに使うのか、というと、マルチバイト文字が混在する状態で
罫線などのテキストの列位置を揃えたい、というときに使います。

例えば、以下のような表の場合です。

```
| test code    |
| テストコード |
```

1行あたりの文字の数と、ターミナル上に表示されるときにテキストの幅は一致しません。
単純に1文字の幅を半角１文字としてプログラムから扱おうとすると、罫線の位置がずれてしまいます。
これを[東アジアの文字幅](https://ja.wikipedia.org/wiki/%E6%9D%B1%E3%82%A2%E3%82%B8%E3%82%A2%E3%81%AE%E6%96%87%E5%AD%97%E5%B9%85)の問題というようです。

以下にずれてしまう例と、今回追加したeastasianwidthでの実装例と実行結果を示します。

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

実行結果

![実行結果](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/69665/9e0c0e37-609d-b6e9-e27d-49ecedb69da3.png)
※Qiita上の表示だと等幅フォントでないためか、表示がずれるので画面キャプチャ

今回はこのパッケージをNimのpackagesリポジトリに登録するまでの流れを追っていきます。

# 追加する手順

## 大まかな流れ

ざっくりパッケージ追加までの流れを説明すると以下のようになります。

- `nimble init`でプロジェクトを作成する
  - 作成するときは*libraly*のプロジェクトとして作成する
- 実装する
- パッケージの説明をREADMEに書く
- `nimble publish`でパッケージ登録のPullRequestを投げる
- マージされる（終了）

## 流れの詳細

### プロジェクトの作成

プロジェクトを作成します。
プロジェクトの作成は`nimble init`を使用します。

`nimble`についてはQiitaの記事でまとめてくださっている方がいらっしゃるのでそちらを参照してください。
[Nimble入門](https://qiita.com/nemui-fujiu/items/2a959bd6cbfe7ff35528)

ディレクトリ名がデフォルトのパッケージ名となります。
以下はhogeというディレクトリ配下で実行したときの結果です。

```
$ pwd
/tmp/hoge

$ nimble init
      Info: Package initialisation requires info which could not be inferred.
        ... Default values are shown in square brackets, press
        ... enter to use them.
      Using "hoge" for new package name
      Using "jiro4989" for new package author
      Using "src" for new package source directory
    Prompt: Package type?
        ... Library - provides functionality for other packages.
        ... Binary  - produces an executable for the end-user.
        ... Hybrid  - combination of library and binary
        ... For more information see https://goo.gl/cm2RX5
     Select Cycle with 'Tab', 'Enter' when done
   Choices: library
            binary
            hybrid
```

一番最初の選択肢の*library*を選択しておきます。
それ以降の記載は必要に応じて変更してください。
（僕は全部空にして作った気がします）

### 実装

実装します。
`nimble init`したときにsrcディレクトリ配下に、パッケージ名の.nimファイルが生成されていると思います。
こちらに必要な機能を追加します。

実装して、可能ならテストコードも書いておくと良いと思います。
TravisCIとかでCIを回すのもやっておいたほうがよいと思います。
なくても登録はしてもらえるかもしれませんが、あったほうがより安心できます。

一応僕が作成したパッケージではテストコードとTravisCIで自動テストするようにしています。
https://github.com/jiro4989/eastasianwidth/blob/master/.travis.yml
参考になれば幸いです。

### パッケージ説明の記載

READMEにパッケージの説明と使い方を書きます。
これを書いていないと、PullRequest時にレビュワーの方に説明を書くことを求められます。
他のPullRequestで、レビュワーが記載を求めているのを目撃したので、きちんと内容を精査してくれているようです。

### PullRequestの発行

`nimble publish`を実行することで、リポジトリをnimのpackagesリポジトリに登録できます。
やっていることは実はシンプルで、
packagesリポジトリのForkを作ってPullRequestを投げているだけです。

https://github.com/nim-lang/packages/blob/master/packages.json
を参照すると、ここに登録されているリポジトリの情報が書かれています。
`nimble publish`は、ここに記載するべき情報を入力した状態の
リポジトリForkを作成し、PullRequestを作成します。

以下は`nimble publish`を実行したときのログです。

```
$ nimble publish
      Info: Please create a new personal access token on Github in order to allow Nimble to fork the packages repository.
      Hint: Make sure to give the access token access to public repos (public_repo scope)!
      Info: Your default browser should open with the following URL: https://github.com/settings/tokens/new
    Prompt: Personal access token?
    Answer: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      Info: Writing access token to file:/home/jiro4989/.nimble/github_api_token
   Success: Verified as jiro4989
      Info: Waiting 10s to let Github create a fork
    Copying packages fork into: /tmp/nimble-packages-fork
   Updating the fork
    Prompt: Whitespace separated list of tags?
    Answer: ※半角空白区切りでタグ情報を入力
    Pushing to remote of fork.
       Info Creating PR
Error: unhandled exception: Connection was closed before full request has been made [ProtocolError]
```

アクセストークンを発行していなかったため、
入力プロンプトでアクセストークンを追加しています。

実は僕が`nimble publish`を実行した時、途中でエラーが発生して処理が中断されてしまいました。
具体的には、packagesリポジトリがforkされてjsonファイルが更新されたのですが
PullRequestが作成されませんでした。

パッケージの仕組みはわかっていたので、PullRequestは手動で送りましてマージされるにいたりました。
PullRequestを送ってからマージされるまでは１日かかってなかったです。

以下は実際に`nimble publish`して、手動でPullRequestしたときものです。
https://github.com/nim-lang/packages/pull/1046

### マージ

めでたくマージされました。
試しに手元で`nimble install eastasianwidth`を実行してみます。

```
$ nimble install eastasianwidth

Downloading https://github.com/jiro4989/eastasianwidth using git
  Verifying dependencies for eastasianwidth@0.1.0
 Installing eastasianwidth@0.1.0
    Prompt: eastasianwidth@0.1.0 already exists. Overwrite? [y/N]
    Answer: y
   Success: eastasianwidth installed successfully.
```

無事インストールできました。
nimのソースからも、パッケージの機能にアクセスできるようになりました。

# まとめ

自作したパッケージをNimのpackagesリポジトリに追加する流れについて説明しました。

パッケージ追加に必要な情報は`nimble init`で揃いますし、
パッケージ登録は`nimble publish`でほぼ完結します。(今回は失敗してますが)
登録の仕組みも単純なので、手動で追加することも容易です。
パッケージの登録は思いの外単純で、簡単あることが伝わったかと思います。

この記事が誰かの参考になって、Nimがもっと発展してくれればなぁと思います。
