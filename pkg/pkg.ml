#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let lwt = Conf.with_pkg ~default:false "lwt"
let mirage = Conf.with_pkg ~default:false "mirage"
let tls = Conf.with_pkg ~default:false "tls"

let () =
  Pkg.describe "logs-syslog" @@ fun c ->
  let lwt = Conf.value c lwt
  and mirage = Conf.value c mirage
  and tls = Conf.value c tls
  in
  Ok [
    Pkg.mllib "src/logs-syslog.mllib" ;
    Pkg.mllib "src/logs-syslog-unix.mllib" ;
    Pkg.mllib ~cond:lwt "src/logs-syslog-lwt.mllib" ;
    Pkg.mllib ~cond:(lwt && tls) "src/logs-syslog-lwt-tls.mllib" ;
    Pkg.mllib ~cond:mirage "src/logs-syslog-mirage.mllib" ;
    Pkg.mllib ~cond:(mirage && tls) "src/logs-syslog-mirage-tls.mllib" ;
  ]
