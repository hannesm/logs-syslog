#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  Pkg.describe "logs-syslog" @@ fun c ->
  Ok [
    Pkg.mllib "src/logs-syslog.mllib" ;
    Pkg.mllib "src/logs-syslog-unix.mllib"
  ]
