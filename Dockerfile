FROM docker.io/ocaml/opam
USER root
RUN opam install dune containers fmt
RUN opam install mparser re ptime oseq seq diet
RUN opam install yojson fileutils
RUN opam install utop ocp-indent
RUN opam install alcotest crowbar
RUN opam install js_of_ocaml js_of_ocaml-ppx lwt_ppx
RUN opam install js_of_ocaml-lwt qcheck qcheck-alcotest
