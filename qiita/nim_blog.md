AsciiDocとNimでGitHubPages上にブログを作ってみた
================================================

# はじめに

AsciiDocとNimでGitHubPages上にブログを作ってみました。

作ったサイトはこちら
https://jiro4989.github.io/index.html

![blog.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/69665/f8df166b-a72c-77c2-6ec6-c6db4ebfc006.png)

なぜそのようなことをしたのかと、どうやって実現したのかについて話します。

# なぜそのようなことをしたのか

このサイトを作る前にhugoとMarkdownでブログを作っていました。
Markdownも嫌いではないのですが、「技術系の記事を書くには表現力が弱い」と感じていました。
よって、最近ではAsciiDocで技術メモを取っています。

AsciiDocを書いていてinclude機能が非常に便利で、これを使えば
「もしかしたらブログの真似事がAsciiDocだけで実現できるのでは」
という疑問を覚えました。この疑問を解消するべく、実装してみた次第です。

# AsciiDocとは

技術文書などを書くのに便利な軽量マークアップ言語です。
Markdownよりも表現力に長けていて、HTMLよりは人間に優しい記法です。

AsciiDocでは別のファイルをファイル内に展開するincludeという機能があります。
今回の試みではこのincludeという機能をフル活用してブログっぽいことを実現しました。

AsciiDocについては以下の記事がとても参考になります。

- [脱Word、脱Markdown、asciidocでドキュメント作成する際のアレコレ](https://qiita.com/tamikura@github/items/5d3f62dae55617ee42bb)
- [AsciiDoc入門](https://qiita.com/xmeta/items/de667a8b8a0f982e123a)

# Nimで何をやったのか

Nimではブログに必要なカテゴリ一覧の生成や最新の記事の取得、
AsciiDocからHTMLを生成して所定の階層構造で配置したりするのに使用しています。
Go言語製の静的サイトジェネレータのhugoと同じようなことをやっています。

ソースコードはこちら。結構泥臭くて、あまりいい感じに実装できてないですが・・・。
https://github.com/jiro4989/jiro4989.github.io/blob/master/src/mngtool.nim

そんなに複雑なことをしていないのでbashでやっても良かったのですが、Nimを採用しました。
理由としては、スクリプトの肥大化が当初から予想されたからです。
(実際に現時点で200行以上のスクリプトになっていることからもその予想は正しかった)

Bashはスクリプトが100行以上になるなら別の言語に切り替えるべし、と言われているのでそれにならった形です。

# 実装

構築されたサイトを解説します。
このサイトのページ種類としては、以下の3つに分類されます。

1. トップページ
1. 目次ページ
1. 記事

## トップページ

すべてのページはヘッダ要素とボディ要素、フッタ要素の3つから構成されています。
加えて、トップページには「最新の記事」と「カテゴリ一覧」が存在します。
これらの要素はすべてAsciiDocのinclude機能で実現しています。

### ボディ要素

AsciiDocのボディ要素を記載します。

```adoc
= 次ログ
// 記事のタグ
// 独自記法のためコメントで表現
// :tag: [top, home]

次郎 (Jiro)のホームページです。
技術関連のメモを中心に残しています。

== サイト情報

* SNS
** https://twitter.com/jiro_saburomaru[Twitter - @jiro_saburomaru] 思考を垂れ流している
* 技術関連
** link:./home/tech/index.html[技術カテゴリ] このサイトのメインコンテンツ
** https://github.com/jiro4989[GitHub - jiro4989] 成果物は全部ここにある
*** https://github.com/jiro4989/jiro4989.github.io/tree/master[jiro4989/jiro4989.github.io] このブログのソースコード
** http://b.hatena.ne.jp/jiroron666/bookmark[はてなブックマーク] よかったと思った記事はここに登録している

include::new-pages.txt[]

include::categories.txt[]
```

下の方に`include::`という記載があります。
これが外部ファイルの読み込み記法です。

このAsciiDocと同じ階層にこれらのファイルを配置した状態でHTMLを生成のコマンドを実行することで
includeしたテキストファイルの中身の展開されたHTMLが生成されます。

includeしているファイルの中身はそれぞれ下記のとおりです。

```new-pages.txt
== 最新の更新された記事 (10件)

* link:./home/tech/sqlite/basic.html[SQLite3環境構築と基本的な使い方] 2019/05/02 09:38:24 更新
* link:./home/tech/nim/multibyte.html[Nimでマルチバイト文字を扱う] 2019/05/02 09:38:24 更新
* link:./home/tech/nim/js.html[NimでJavaScriptとして出力しHTMLから利用する] 2019/05/02 09:38:24 更新
* link:./home/tech/shell/shellgei-studygroup-vol41.html[第41回 シェル芸勉強会振り返り] 2019/05/02 09:38:24 更新
```

```categories.txt
== カテゴリ一覧

* link:./home/index.html[home] [4]
** link:./home/tech/index.html[tech] [4]
*** link:./home/tech/shell/index.html[shell] [1]
*** link:./home/tech/nim/index.html[nim] [2]
*** link:./home/tech/sqlite/index.html[sqlite] [1]
```

拡張子をtxtとしていますが、AsciiDoc記法のテキストファイルです。
Nimでこれらのテキストを生成しています。

### ヘッダとフッタ要素

ヘッダとフッタはlayout.txtというファイルを使用して以下のように取り込んでいます。

```layout.txt
include::metadata.txt[]

include::body.adoc[]

include::footer.txt[]
```

このファイルをビルドすることでページができあがります。
仕組みとしては以下の図を参照してください。

```
repository-root/
  +- tmpl/
  |   +- index-footer.txt
  |   +- index-metadata.txt
  |   +- layout.txt
  |   +- page-footer.txt
  |   +- page-metadata.txt
  |   `- top-footer.txt
  |
  +- work/
  |   +- body.adoc       <- page/index.adocをコピー
  |   +- categories.txt  <- 動的に生成
  |   +- footer.txt      <- tmpl/配下からコピー
  |   +- layout.txt      <- tmpl/配下からコピー。ビルド対象に指定
  |   +- metadata.txt    <- tmpl/配下からコピー
  |   `- new-pages.txt   <- 動的に生成
  |
  `- page/
      `- index.adoc
```

テンプレートファイルとメモとして書いたAsciiDocファイルを
作業用ディレクトリにコピーしてきてビルドし、所定の場所へ配置しています。

目次ページと記事ページも同じアプローチで生成しています。
違うのはincludeするファイルだけで、テンプレートからのファイルコピーのときに切り替えているだけです。
詳細は割愛します。

### HTMLの生成

Nimから外部コマンドのdockerを実行して生成しています。

AsciiDocの生成にはいろいろ依存するものが多いので、
環境構築に手間がかかるのも嫌だし、ということでDockerコンテナ内に
もろもろの依存ライブラリを閉じるようにしています。

これでAsciiDocをHTMLに変換するにはDockerだけで良い状態です。

```nim
let uid = getuid()
let gid = getgid()
let cwd = getCurrentDir()
discard execProcess(&"docker run --rm -u {uid}:{gid} -v {cwd}:/documents/ asciidoctor/docker-asciidoctor asciidoctor -r asciidoctor-diagram {f}")
```

このコマンドを実行すると、AsciiDocと同じ階層に
拡張子がhtmlになった同じファイル名のものが生成されます。

# まとめ

AsciiDocとNimでブログのようなものを構築できることがわかりました。

AsciiDocは見た目をCSSで変更できるので、それなりに見た目もこだわれます。
こちらのサイトにAsciiDoc用のテーマとデモページがあります。
https://github.com/darshandsoni/asciidoctor-skins

当然ながら、AsciiDocは技術文書を書くのに長けたものであってテンプレートエンジンではありません。
足りない機能は自力でスクリプトとして用意する必要があったりと、それなりに大変でした。

実装にかかった期間はGW期間のうち丸2日でした。

GitHubPagesだけだと記事内容の全文検索ができなかったりAsciiDocだと
JSを使った動的に変化するページが作れなかったりといろいろ制約があります。
ホントに一昔前の静的HTMLとリンクだけで構築されたようなブログを作るのが限界かな、と感じました。

GitHubPages上でAsciiDocを使用して構築することのメリットは僕が思いつく限りだと以
下のとおりです。

1. TravisCIなどで自動で何かを回せる
  1. textlintにかけて文章の自動添削をする
  1. 自動でGitHubPagesにプッシュする
1. 記事は普通のAsciiDocなのでブログ移転することになっても再利用性と移植性が高い
1. スクリプトでどこまでいじり回せるし、HTML生成時に作れるページならなんでも作れる
1. AsciiDocをHTMLでなくPDFに変換して共有できる

まぁメンテと運用コストが高いですし、
コンテンツ検索がほとんどできないので
ブラウザから閲覧する技術メモ環境としては不便です。

ぶっちゃけると、AsciiDocでもにょもにょ頑張るよりかは
ScrapBox使ったほうがもっと便利で使い勝手良いです。

以上です。
