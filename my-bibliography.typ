#import "default-style.typ": default-style

#let cited-keys = state("custom-bibliography-cited-keys", ())

#let is-reference-record(value, key) = {
  (
    type(value) == dictionary
    and "kind" in value
    and value.kind == "reference"
    and "key" in value
    and value.key == key
  )
}

#let records-for(key) = {
  query(label(key))
    .map(element => element.value)
    .filter(record => is-reference-record(record, key))
}

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

  [#update #link(label("custom-bibliography-entry-" + key), rendered)]
}

#let cite(
  key,
  supplement: none,
  form: "normal",
  style: auto,
) = context {
  let key = str(key)
  let records = records-for(key)
  assert(
    records.len() == 1,
    message: "Expected exactly one bibliography containing key: " + key,
  )

  render-citation(records.first(), key, supplement, form, style)
}

#let route-reference(element) = context {
  let key = str(element.target)
  let records = records-for(key)

  if records.len() == 0 {
    element
  } else {
    assert(
      records.len() == 1,
      message: "Reference key occurs in multiple bibliographies: " + key,
    )

    let supplement = if element.supplement == auto {
      none
    } else {
      element.supplement
    }

    render-citation(records.first(), key, supplement, "normal", auto)
  }
}

#let setup(body) = {
  show ref: route-reference
  body
}

#let register-reference-labels(references, renderer) = {
  for key in references.keys() {
    [
      #metadata((
        kind: "reference",
        key: key,
        entry: references.at(key),
        style: renderer,
      ))
      #label(key)
    ]
  }
}

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
          #label("custom-bibliography-entry-" + key)
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
