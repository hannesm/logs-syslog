#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let lwt = Conf.with_pkg ~default:false "lwt"
let mirage = Conf.with_pkg ~default:false "mirage"
let lwt_tls = Conf.with_pkg ~default:false "lwt-tls"
let mirage_tls = Conf.with_pkg ~default:false "mirage-tls"

let () =
  Pkg.describe "logs-syslog" @@ fun c ->
  let lwt = Conf.value c lwt
  and mirage = Conf.value c mirage
  and lwt_tls = Conf.value c lwt_tls
  and mirage_tls = Conf.value c mirage_tls
  in
  Ok [
    Pkg.mllib "src/logs-syslog.mllib" ;
    Pkg.mllib "src/logs-syslog-unix.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_lwt"] ~cond:lwt "src/logs-syslog-lwt.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_lwt_tls"] ~cond:lwt_tls "src/logs-syslog-lwt-tls.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_mirage"] ~cond:mirage "src/logs-syslog-mirage.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_mirage_tls"] ~cond:mirage_tls "src/logs-syslog-mirage-tls.mllib" ;
  ]
