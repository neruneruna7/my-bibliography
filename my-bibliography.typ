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
// #import "my-bibliography.typ": bibliography, cite, setup
// #import "style.typ": style
// #show: setup
// @bib:du2025sok[p. 42]
// #cite(<bib:du2025sok>, form: "author")
// #bibliography("references.toml", style: style)
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

// 指定した文献を本文中に表示する。`key` は `bib:` prefix を含む label で指定する。
// `supplement` はページ番号など、`form` は引用形式、`style` は renderer に渡す補助情報である。
// 使用例:
// #cite(<bib:du2025sok>)
// #cite(<bib:du2025sok>, supplement: [p. 42], form: "author")
#let cite(
  key,
  supplement: none,
  form: "normal",
  style: auto,
) = context {
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

// 文書全体の ref show rule を設定し、`@bib:key` を独自 cite 処理へ送る。
// 使用例:
// #show: setup
// @bib:du2025sok
#let setup(body) = {
  show ref: route-reference
  body
}

// TOML の全キーについて、補完と citation query に使う metadata と label を登録する。
// bibliography() が呼び出す内部関数である。
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

// TOML を読み込み、文献 label を登録して参考文献一覧を生成する。
// `full: false` は引用済み文献のみ、`full: true` は TOML の全項目を表示する。
// `style: auto` は default-style を使い、明示した場合は `cite` / `entry` renderer を使う。
// 使用例:
// #import "my-bibliography.typ": bibliography, cite, setup
// #import "style.typ": style
// #show: setup
// 
// #bibliography("references.toml", title: none, style: style)
#let bibliography(
  sources,
  title: auto,
  full: false,
  style: auto,
  target: auto,
  group: auto,
) = {
  assert(type(sources) == str, message: "sources must be a TOML file path")
  assert(type(full) == bool, message: "full must be a boolean")

  let document = toml(sources)
  assert("references" in document, message: "TOML must contain [references.*] tables")
  let references = document.references
  let renderer = if style == auto { default-style } else { style }
  assert("cite" in renderer, message: "style.cite is required")
  assert("entry" in renderer, message: "style.entry is required")

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
