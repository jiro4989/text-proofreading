JSONからNimのObject定義を生成するコマンドnimjsonを作った
==============================================

# はじめに

NimでJSONを読み込んでObjectに変換するとき、以下のように実装します。

```point.json
{"x":10, "y":20}
```

```nim
import json

type
  Point = ref object
    x: int
    y: int

let point = parseFile("point.json").to(Point)
echo point[]
```

`to`でオブジェクトマッピングするにはObject定義が必要です。
しかしながら、JSONが複雑な構造をしていたり、非常に大量のキーを持っていたりした際に
それを手動で定義するのは非常に大変な作業です。

今回作成した`nimjson`はこの問題を少しでも簡単にするためのコマンドです。
[gojson](https://github.com/ChimeraCoder/gojson)というJSONからGoの構造体定義を生成するツールに影響を受けました。

# インストール

Nimのバージョンは下記の通り。

    % nim -v
    Nim Compiler Version 0.20.0 [Linux: amd64]
    Compiled at 2019-06-06
    Copyright (c) 2006-2019 by Andreas Rumpf

    git hash: e7471cebae2a404f3e4239f199f5a0c422484aac
    active boot switches: -d:release

    % nimble -v
    nimble v0.10.2 compiled at 2019-06-15 22:10:02
    git hash: couldn't determine git hash

インストールコマンド。

```bash
nimble install nimjson
```

コマンドだけ必要な場合は[Release](https://github.com/jiro4989/nimjson/releases)からバイナリをダウンロードしてください。

# 使い方

非常に簡単なJSONからNimのObject定義を生成してみます。

```bash
% echo '{"x":10.0, "y":20.0, "width":144, "height":144}' | nimjson
type
  NilType = ref object
  Object = ref object
    x: float64
    y: float64
    width: int64
    height: int64
```

nimjsonのリポジトリの情報からNimのObject定義を生成してみます。

```bash
% curl -s https://api.github.com/repos/jiro4989/nimjson | nimjson -O:Repository
type
  NilType = ref object
  Repository = ref object
    id: int64
    node_id: string
    name: string
    full_name: string
    private: bool
    owner: Owner
    html_url: string
    description: string
    fork: bool
    url: string
    forks_url: string
    keys_url: string
    collaborators_url: string
    teams_url: string
    hooks_url: string
    issue_events_url: string
    events_url: string
    assignees_url: string
    branches_url: string
    tags_url: string
    blobs_url: string
    git_tags_url: string
    git_refs_url: string
    trees_url: string
    statuses_url: string
    languages_url: string
    stargazers_url: string
    contributors_url: string
    subscribers_url: string
    subscription_url: string
    commits_url: string
    git_commits_url: string
    comments_url: string
    issue_comment_url: string
    contents_url: string
    compare_url: string
    merges_url: string
    archive_url: string
    downloads_url: string
    issues_url: string
    pulls_url: string
    milestones_url: string
    notifications_url: string
    labels_url: string
    releases_url: string
    deployments_url: string
    created_at: string
    updated_at: string
    pushed_at: string
    git_url: string
    ssh_url: string
    clone_url: string
    svn_url: string
    homepage: string
    size: int64
    stargazers_count: int64
    watchers_count: int64
    language: string
    has_issues: bool
    has_projects: bool
    has_downloads: bool
    has_wiki: bool
    has_pages: bool
    forks_count: int64
    mirror_url: NilType
    archived: bool
    disabled: bool
    open_issues_count: int64
    license: License
    forks: int64
    open_issues: int64
    watchers: int64
    default_branch: string
    network_count: int64
    subscribers_count: int64
  Owner = ref object
    login: string
    id: int64
    node_id: string
    avatar_url: string
    gravatar_id: string
    url: string
    html_url: string
    followers_url: string
    following_url: string
    gists_url: string
    starred_url: string
    subscriptions_url: string
    organizations_url: string
    repos_url: string
    events_url: string
    received_events_url: string
    type: string
    site_admin: bool
  License = ref object
    key: string
    name: string
    spdx_id: string
    url: string
    node_id: string
```

型がnullのときはNilTypeが定義されます。
NilTypeがセットされるのは以下の2ケースです。

1. 値がnullである
2. 配列の最初の要素がnullである

NilTypeが嫌な場合は手動で修正する必要があります。
あるいは元のJSONにnullでない値をセットして再度nimjsonを実行する必要があります。

# 実装の参考

gojsonから参考にしたのは達成したいことに対するコマンドのIn/Outのインタフェースを参考にしました。
内部実装で参考にしたのはNimの標準ライブラリ`json`の`toUgry`というプロシージャのロジックです。

```nim
proc toUgly*(result: var string, node: JsonNode) =
  ## Converts `node` to its JSON Representation, without
  ## regard for human readability. Meant to improve ``$`` string
  ## conversion performance.
  ##
  ## JSON representation is stored in the passed `result`
  ##
  ## This provides higher efficiency than the ``pretty`` procedure as it
  ## does **not** attempt to format the resulting JSON to make it human readable.
  var comma = false
  case node.kind:
  of JArray:
    result.add "["
    for child in node.elems:
      if comma: result.add ","
      else:     comma = true
      result.toUgly child
    result.add "]"
  of JObject:
    result.add "{"
    for key, value in pairs(node.fields):
      if comma: result.add ","
      else:     comma = true
      key.escapeJson(result)
      result.add ":"
      result.toUgly value
    result.add "}"
  of JString:
    node.str.escapeJson(result)
  of JInt:
    when defined(js): result.add($node.num)
    else: result.add(node.num)
  of JFloat:
    when defined(js): result.add($node.fnum)
    else: result.add(node.fnum)
  of JBool:
    result.add(if node.bval: "true" else: "false")
  of JNull:
    result.add "null"
```

NimでJSON文字列をパースして得られるオブジェクトの`JsonNode`は(個人的には)特殊な型で、
`kind`フィールドの型によってアクセス可能なフィールドが決まるという型です。
以下のように、`kind`の型によって分岐するような実装になっている。

```nim
type
  JsonNode* = ref JsonNodeObj ## JSON node
  JsonNodeObj* {.acyclic.} = object
    case kind*: JsonNodeKind
    of JString:
      str*: string
    of JInt:
      num*: BiggestInt
    of JFloat:
      fnum*: float
    of JBool:
      bval*: bool
    of JNull:
      nil
    of JObject:
      fields*: OrderedTable[string, JsonNode]
    of JArray:
      elems*: seq[JsonNode]
```

これをどう活用すれば目的を達成できるか、について大いに参考にしました。

# 最後に

NimでJSONを扱う際の助けになれば幸いです。
