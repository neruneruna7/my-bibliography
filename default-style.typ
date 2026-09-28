#let author-name(author) = author.given + " " + author.family

#let author-list(entry) = entry.authors.map(author-name).join(", ")

#let render-entry(entry, ctx) = [
  (#ctx.number) #author-list(entry), #entry.title (#entry.year)
]

#let append-supplement(body, supplement) = {
  if supplement == none {
    body
  } else {
    [#body, #supplement]
  }
}

#let render-cite(entry, ctx) = {
  assert(
    ctx.form in ("normal", "prose", "full", "author", "year", "none"),
    message: "Unsupported citation form: " + ctx.form,
  )

  let normal = if ctx.supplement == none {
    [#text("[")#ctx.number#text("]")]
  } else {
    [#text("[")#ctx.number#text(", ")#ctx.supplement#text("]")]
  }

  if ctx.form == "normal" {
    normal
  } else if ctx.form == "prose" {
    append-supplement([#author-list(entry) (#entry.year)], ctx.supplement)
  } else if ctx.form == "full" {
    append-supplement(render-entry(entry, ctx), ctx.supplement)
  } else if ctx.form == "author" {
    append-supplement(author-list(entry), ctx.supplement)
  } else if ctx.form == "year" {
    append-supplement(str(entry.year), ctx.supplement)
  } else {
    []
  }
}

#let default-style = (
  cite: render-cite,
  entry: render-entry,
)
