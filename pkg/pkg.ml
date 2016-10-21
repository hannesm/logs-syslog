#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let lwt = Conf.with_pkg ~default:false "lwt"

let () =
  Pkg.describe "logs-syslog" @@ fun c ->
  let lwt = Conf.value c lwt in
  Ok [
    Pkg.mllib "src/logs-syslog.mllib" ;
    Pkg.mllib "src/logs-syslog-unix.mllib" ;
    Pkg.mllib ~cond:lwt "src/logs-syslog-lwt.mllib"
  ]
