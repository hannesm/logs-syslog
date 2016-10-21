#!/bin/sh -x

export OPAMYES=1
eval `opam config env`
opam install mirage
cd example
mirage configure -t unix
make

