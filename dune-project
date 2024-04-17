(lang dune 3.15)
(using menhir 2.1)

(name kontos)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name")

(maintainers "Maintainer Name")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name kontos)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml dune ocamllex menhir)
 (tags
  (topics "to describe" your project)))
