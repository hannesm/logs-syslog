#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let lwt = Conf.with_pkg ~default:false "lwt"
let mirage = Conf.with_pkg ~default:false "mirage"
let tls = Conf.with_pkg ~default:false "tls"

let () =
  let opams = [ Pkg.opam_file "opam" ~lint_deps_excluding:(Some ["io-page"]) ] in
  Pkg.describe ~opams "logs-syslog" @@ fun c ->
  let lwt = Conf.value c lwt
  and mirage = Conf.value c mirage
  and tls = Conf.value c tls
  in
  Ok [
    Pkg.mllib "src/logs-syslog.mllib" ;
    Pkg.mllib "src/logs-syslog-unix.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_lwt"] ~cond:lwt "src/logs-syslog-lwt.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_lwt_tls"] ~cond:(lwt && tls) "src/logs-syslog-lwt-tls.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_mirage"] ~cond:mirage "src/logs-syslog-mirage.mllib" ;
    Pkg.mllib ~api:["Logs_syslog_mirage_tls"] ~cond:(mirage && tls) "src/logs-syslog-mirage-tls.mllib" ;
  ]
