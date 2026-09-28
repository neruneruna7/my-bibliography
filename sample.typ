#import "my-bibliography.typ": bibliography, cite, setup
#import "style.typ": style

#show: setup

= Test



@bib:du2025sok[p. 42]

#cite(<bib:du2025sok>, supplement: [p. 42], form: "author")


#bibliography("references.toml")

// #std.bibliography("")