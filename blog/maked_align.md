テキストを左右中央寄せするalignコマンドをGoで作った
===============================================

テキストを左右中央寄せするalignコマンドをGoで作りました。
なぜ作ったのか、と何ができるのか、について記載します。

[:contents:]

# なぜ作ったのか

[シェル芸bot](https://twitter.com/minyoruminyon)環境で位置揃えを簡単にできるようにしたかったからです。
シェル芸bot環境では基本的にTwitterの140文字が文字数の限界で
（引用リツイートを使うことで140文字以上入力することも可能ですが）
文字数を少しでも削りたい、という思いで作りました。

# 位置揃えの例

例えば以下のテキストがあります。

```text
12345
abc
zzzzzzzzzzzzzzz
```

このテキストを右揃えするシェルは下記のようになります。

```bash
#!/bin/bash

align_right() {
  local p="$1"
  local max_line_width=0
  local lines=()
  while read -r line; do
    lines+=("$line")
    width=$(echo "$line" | wc -c)
    if [ "$max_line_width" -lt "$width" ]; then
      max_line_width=$width
    fi
  done

  for line in ${lines[@]}; do
    width=$(echo "$line" | wc -c)
    diff=$((max_line_width - width))
    pad=$(seq $diff | xargs -I@ echo -n "$p")
    echo "$pad$line"
  done
}

cat << EOS | align_right " "
12345
abc
zzzzzzzzzzzzzzz
EOS
```

無事実装できました。
中央寄せも同じように実装できます。

ただ毎回こんなのを実装するのも面倒ですし、
これだど日本語が混在するテキストの場合にきちんと位置を揃えられません。
位置揃えに使える文字も半角文字に限定されます。

入力のテキストに全角文字が混在していてもいい感じに処理できて、
位置揃えに全角文字も指定できるようにしたのが
今回作成した`align`コマンドです。

# alignコマンドの使い方

前述の例を`align`を使うように書きかえると以下のようになります。

```bash
cat << EOS | align right -p " "
12345
abc
zzzzzzzzzzzzzzz
```

実行結果はこちら。

```
          12345
            abc
zzzzzzzzzzzzzzz
```

サブコマンドにはleft, center, rightが指定できます。
全角文字が混在する場合の例は下記。

```bash
cat << EOS | align right -p " "
あいうえお
abc
zzzzzzzzzzzzzzz
EOS
```

実行結果はこちら。

```
     あいうえお
            abc
zzzzzzzzzzzzzzz
```

無事、きちんと位置を揃えられています。

# 実装

位置を揃えるロジックについては前述のbashのコードと
同じようなことをやっています。

1. 一番長い文字幅を取得する
2. 差分を文字で埋める

重要なのは「文字幅をどう取得するか」です。

alignでは[go-runewidth](https://github.com/mattn/go-runewidth)という外部ライブラリを使用することで
文字列の見た目上の文字幅を取得しています。

go-runewidthでは「全角文字なら文字幅2」「半角文字なら文字幅1」という具合に
見た目上のテキストの幅を返してくれます。
これを利用し、位置を揃えるようにしています。

Goで実装した箇所を抜粋します。

```go
func MaxStringWidth(lines []string) (max int) {
	for _, v := range lines {
		l := runewidth.StringWidth(v)
		if max < l {
			max = l
		}
	}
	return max
}

// AlignRight は文字列を右寄せする。
// 右寄せは見た目上の文字列の長さで揃える。
// length = -1のときは、引数文字列の最長の長さに合わせる。
// padは埋める文字列を指定する。埋める文字が見た目上でマルチバイトの場合は
// たとえlengthが奇数でも+1して偶数になるように調整する。
func AlignRight(lines []string, length int, pad string) []string {
	if length == 0 || len(lines) < 1 {
		return lines
	}

	// 空白埋めする文字列がマルチバイト文字かどうか
	padWidtn := runewidth.StringWidth(pad)
	padIsMultiByteString := padWidtn == 2

	// -1のときは文字列の長さをalignの長さにする
	// パッディングの長さと、処理対象の文字列のより長い方を揃える数値に指定
	maxWidth := MaxStringWidth(lines)
	if length == -1 {
		length = maxWidth
	} else if length < maxWidth {
		length = maxWidth
	}

	// マルチバイト文字を使うときは長さを偶数に揃える
	if padIsMultiByteString && length%2 != 0 {
		length++
	}

	ret := []string{}
	for _, line := range lines {
		l := runewidth.StringWidth(line)
		diff := length - l
		if diff%2 != 0 {
			line = " " + line
			diff--
		}
		// Repeatするときにマルチバイト文字を使うときは2分の1にする
		if padIsMultiByteString {
			diff /= 2
		}
		s := strings.Repeat(pad, diff) + line
		ret = append(ret, s)
	}
	return ret
}
```

# まとめ

自作のコマンド`align`についてとその実装について一部紹介しました。

この程度ならシェルスクリプトだけでも実現できるようにも思いましたが
Goの勉強もしたかったのでGoで実装しました。

# 余談

こういう自作のコマンドをはてなブログに書くかScrapboxに書くかQiitaに書くか悩みます。
前まではQiitaに書いてたけれど、自作のコマンドの紹介とかははてなブログに
書いたほうが良いみたい。

まぁQiitaは一般的な技術的TIPS、事実を述べる場所で
自作のコマンドは「作った人個人」に紐づくと考えると
ブログに書くのが適当なのも納得がいきました。

Scrapboxに書くことも検討したんですが、Scrapboxは意図的に
外部に広く知ってもらう機能を実装していないそうです。
それだとせっかく作ったツールを知ってもらいたくても知ってもらえないように
感じたので書かないことにしました。

Scrapbox自体はすごく良いサービスなので、
社内WikiとかプロジェクトのWikiとしてはぜひ使ってみたいです。
