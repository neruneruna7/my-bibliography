// 自前の参考文献管理パッケージ
// デフォルトのものの課題
// - 日本語と英語文献で表示分けができない
// - 表示のカスタマイズが制限されている
// - 表示カスタマイズのファイルがxml形式で，typstとbibに加えさらなる知識を要求する
// 
// そこでこのパッケージを開発する．
// 特徴は次のとおりである（を目指している）
// - デフォルトと極力変わらない書き方
// - tomlファイルによる参考文献管理
//   - 私がyamlのインデント規則を嫌いなので
// - 日本語文献と英語文献で表示を分けられる
//   - 例：日本語なら 著者 他, 英語なら， author, et al
// - 表示規則を，typstの知識のみでカスタムできる
// 
// 参考文献を管理するtomlファイルが使用に必須である．
// 追加要素として，自分でstyleをtypstで記述することができる．
// これをbibliography関数に渡すことで，引用の表示をカスタマイズできる
// 特に指定しない場合，デフォルトの表示が適用される．

// 公開 API の使用例:
// `#import "my-bibliography.typ": bibliography, cite, setup`
// `#import "style.typ": style`
// `#show: setup`
// `@bib:du2025sok[p. 42]`
// `#cite(<bib:du2025sok>, form: "author")`
// `#bibliography("references.toml", style: style)`
#import "default-style.typ": default-style

// TOML のキー `key` に対応する Typst label を `bib:key` とする。
// prefix を変更する場合はこの定数だけを変更する。
#let reference-prefix = "bib:"

// 引用されたキーを文書内の出現順に保持し、再引用時の番号を再利用する。
#let cited-keys = state("custom-bibliography-cited-keys", ())

// label から得た metadata が独自文献レコードであり、指定 label と一致するか調べる。
// 使用例（内部）: is-reference-record(record, reference-prefix + "du2025sok")
#let is-reference-record(value, reference-label) = {
  (
    type(value) == dictionary
    and "kind" in value
    and value.kind == "reference"
    and "reference-label" in value
    and value.reference-label == reference-label
  )
}

// label に付与された文献 metadata を検索する。
// 使用例（内部）: records-for(reference-prefix + "du2025sok")
#let records-for(reference-label) = {
  query(label(reference-label))
    .map(element => element.value)
    .filter(record => is-reference-record(record, reference-label))
}

// 採番、引用済み状態の更新、style.cite の呼び出し、文献一覧へのリンクを行う。
// `cite` と `route-reference` から呼び出す内部関数である。
// 型契約: render-citation(record: dictionary, key: str, supplement: none | content,
//                          form: str, style: auto | str | path | bytes) -> content
// 使用例（内部）: render-citation(record, record.key, none, "normal", auto)
#let render-citation(record, key, supplement, form, style) = context {
  let history = cited-keys.get()
  let position = history.position(candidate => candidate == key)
  let number = if position == none { history.len() + 1 } else { position + 1 }
  let update = cited-keys.update(
    history => if key in history { history } else { history + (key,) },
  )

  let rendered = (record.style.cite)(
    record.entry,
    (
      key: key,
      number: number,
      supplement: supplement,
      form: form,
      style: style,
    ),
  )

  [#update #link(label(reference-prefix + key), rendered)]
}

/// 文献キーを本文中の引用として表示する。キーは `bib:` prefix 付きの label で指定する。
/// - 例: `#cite(<bib:du2025sok>)`。
/// - 補足付きは `#cite(<bib:du2025sok>, supplement: [p. 42])`。
/// - key (label): TOML のキーに `bib:` を付けた label。例は `<bib:du2025sok>`。
/// - supplement (content, none): ページ番号などの補足。省略時は `none`。
/// - form (str): `normal`, `prose`, `full`, `author`, `year`, `none` のいずれか。
/// - style (any): `auto`, 文字列、path、bytes のいずれか。現在は renderer に渡すだけである。
/// -> content
#let cite(
  key,
  supplement: none,
  form: "normal",
  style: auto,
) = context {
  assert(type(key) == label, message: "key must be a label such as <bib:article>")
  assert(
    supplement == none or type(supplement) == content,
    message: "supplement must be none or content",
  )
  assert(
    form in ("normal", "prose", "full", "author", "year", "none"),
    message: "form must be normal, prose, full, author, year, or none",
  )
  let citation-style-type = type(style)
  assert(
    style == auto
      or citation-style-type == str
      or citation-style-type == path
      or citation-style-type == bytes,
    message: "style must be auto, str, path, or bytes",
  )

  let reference-label = str(key)
  assert(
    reference-label.starts-with(reference-prefix),
    message: "Citation labels must start with " + reference-prefix,
  )
  let records = records-for(reference-label)
  assert(
    records.len() == 1,
    message: "Expected exactly one bibliography containing label: " + reference-label,
  )

  let record = records.first()
  render-citation(record, record.key, supplement, form, style)
}

// `ref` 要素を独自文献へ振り分ける。`bib:` label 以外は元の ref 要素へ戻す。
// 型契約: route-reference(element: content) -> content
// 使用例: `setup` が show rule として登録するため、利用側では `#show: setup` と書く。
#let route-reference(element) = context {
  let reference-label = str(element.target)

  if not reference-label.starts-with(reference-prefix) {
    element
  } else {
    let records = records-for(reference-label)
    if records.len() == 0 {
      element
    } else {
      let record = records.first()
      assert(
        records.len() == 1,
        message: "Reference label occurs in multiple bibliographies: " + reference-label,
      )

      let supplement = if element.supplement == auto {
        none
      } else {
        element.supplement
      }

      render-citation(record, record.key, supplement, "normal", auto)
    }
  }
}

/// 文書内の `@bib:key` を独自の `cite` 処理へ送る show rule を設定する。
/// 利用例: 文書の先頭で `#show: setup` を指定する。
/// - body (content): show rule が受け取る文書本文。
/// -> content
#let setup(body) = {
  show ref: route-reference
  body
}

// TOML の全キーについて、補完と citation query に使う metadata と label を登録する。
// bibliography() が呼び出す内部関数である。
// 型契約: register-reference-labels(references: dictionary, renderer: dictionary) -> content
// 使用例（内部）: register-reference-labels(references, renderer)
#let register-reference-labels(references, renderer) = {
  for key in references.keys() {
    [
      #metadata((
        kind: "reference",
        key: key,
        reference-label: reference-prefix + key,
        entry: references.at(key),
        style: renderer,
      ))
      #label(reference-prefix + key)
    ]
  }
}

/// 参考文献管理関数 
/// TOMLファイルを読み込む．
/// 
/// 表示をカスタマイズする場合は，style関数に与える
/// 
/// 使用例: 
/// ```
/// #import "my-bibliography.typ": bibliography, cite, setup
/// #import "style.typ": style
/// #show: setup
/// #bibliography("references.toml", title: none, style: style)
/// ```
/// - sources (any): `[references.*]` テーブルを持つ単一の TOML ファイル。文字列または path を渡す。
/// - title (auto, content, none): `auto` は文書言語に応じた見出し、`none` は見出しなし、content は指定見出し。
/// - full (bool): `false` は引用済み文献のみ、`true` は TOML 内の全文献を表示する。
/// - style (auto, dictionary): `auto` は既定 style。辞書では `cite` と `entry` に renderer 関数を指定する。
/// - target (any): 標準 bibliography に寄せた予約引数。現在は振り分けに使わない。
/// - group (auto, none, str): 標準 bibliography に寄せた予約引数。現在は採番に使わない。
/// -> content
#let bibliography(
  sources,
  title: auto,
  full: false,
  style: auto,
  target: auto,
  group: auto,
) = {
  let sources-type = type(sources)
  assert(
    sources-type == str or sources-type == path,
    message: "sources must be a TOML file path as str or path",
  )
  assert(
    title == auto or title == none or type(title) == content,
    message: "title must be auto, none, or content",
  )
  assert(type(full) == bool, message: "full must be a boolean")
  assert(
    style == auto or type(style) == dictionary,
    message: "style must be auto or a renderer dictionary",
  )
  assert(
    group == auto or group == none or type(group) == str,
    message: "group must be auto, none, or str",
  )
  let target-type = type(target)
  assert(
    target == auto
      or target-type == function
      or target-type == label
      or target-type == location
      or target-type == selector,
    message: "target must be auto, function, label, location, or selector",
  )

  let document = toml(sources)
  assert("references" in document, message: "TOML must contain [references.*] tables")
  let references = document.references
  let renderer = if style == auto { default-style } else { style }
  assert(
    "cite" in renderer and type(renderer.cite) == function,
    message: "style.cite must be a function (entry, ctx) -> content",
  )
  assert(
    "entry" in renderer and type(renderer.entry) == function,
    message: "style.entry must be a function (entry, ctx) -> content",
  )

  let manifest = metadata((
    kind: "custom-bibliography",
    source: sources,
    references: references,
    style: renderer,
    full: full,
    target: target,
    group: group,
  ))
  let key-labels = register-reference-labels(references, renderer)

  let listing = context {
    let cited = cited-keys.final().filter(key => key in references)
    let remaining = references.keys().filter(key => key not in cited)
    let keys = if full { cited + remaining } else { cited }
    let heading-content = if title == none {
      []
    } else {
      let heading-title = if title == auto {
        if text.lang == "ja" { [参考文献] } else { [References] }
      } else {
        title
      }
      heading(numbering: none, outlined: false)[#heading-title]
    }

    [
      #heading-content
      #for (index, key) in keys.enumerate() {
        let entry = (renderer.entry)(
          references.at(key),
          (key: key, number: index + 1),
        )
        block([
          #entry
        ], below: 0.5em)
      }
    ]
  }

  [
    #manifest
    #key-labels
    #listing
  ]
}
