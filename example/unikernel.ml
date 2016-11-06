open Lwt.Infix

module Main (C:V1_LWT.CONSOLE) (CLOCK:V1.PCLOCK) (T:V1_LWT.TIME) (S:V1_LWT.STACKV4) = struct
  module U = S.UDPV4
  module LU = Logs_syslog_mirage.Udp(C)(CLOCK)(U)

  let start c clock _time s =
    let ip = Ipaddr.V4.of_string_exn "127.0.0.1" in
    let r = LU.create c clock (S.udpv4 s) ~hostname:"MirageOS.example" ip () in
    Logs.set_reporter r ;
    Logs.set_level ~all:true (Some Logs.Debug) ;
    let rec go () =
      Logs_lwt.warn (fun l -> l "foobar") >>= fun () ->
      Logs_lwt.err (fun l -> l "bar foofoobar") >>= fun () ->
      Logs_lwt.info (fun l -> l "foofoobar") >>= fun () ->
      Logs_lwt.debug (fun l -> l "debug foofoobar") >>= fun () ->
      T.sleep_ns (Duration.of_sec 1) >>= fun () ->
      go ()
    in
    go ()

  end
