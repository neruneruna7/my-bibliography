#let short-author(entry) = {
  let first = entry.authors.first()

  if entry.language == "ja" {
    if entry.authors.len() == 1 {
      first.family
    } else {
      first.family + " 他"
    }
  } else {
    let name = first.given + " " + first.family
    if entry.authors.len() == 1 {
      name
    } else {
      name + " et al."
    }
  }
}

#let append-supplement(body, supplement) = {
  if supplement == none {
    body
  } else {
    [#body, #supplement]
  }
}

#let render-entry(entry, ctx) = {
  let author = short-author(entry)
  let venue = if "venue" in entry { ", " + entry.venue } else { "" }

  [
    (#ctx.number) #author, #entry.title#venue (#entry.year)
  ]
}

#let render-cite(entry, ctx) = {
  assert(
    ctx.form in ("normal", "prose", "full", "author", "year", "none"),
    message: "Unsupported citation form: " + ctx.form,
  )

  let author = short-author(entry)
  let numeric = if ctx.supplement == none {
    [#text("[")#ctx.number#text("]")]
  } else {
    [#text("[")#ctx.number#text(", ")#ctx.supplement#text("]")]
  }

  if ctx.form == "none" {
    []
  } else if ctx.form == "normal" {
    numeric
  } else if ctx.form == "prose" {
    append-supplement([#author (#entry.year)], ctx.supplement)
  } else if ctx.form == "full" {
    append-supplement(render-entry(entry, ctx), ctx.supplement)
  } else if ctx.form == "author" {
    append-supplement(author, ctx.supplement)
  } else {
    append-supplement(str(entry.year), ctx.supplement)
  }
}

#let style = (
  cite: render-cite,
  entry: render-entry,
)
