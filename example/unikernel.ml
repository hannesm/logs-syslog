open Lwt.Infix

module Main (C:V1.CLOCK) (T:V1_LWT.TIME) (S:V1_LWT.STACKV4) = struct
  module U = S.UDPV4
  module LU = Logs_syslog_mirage.Udp(C)(U)

  let start _c _t s =
    let r = LU.create (S.udpv4 s) ~hostname:"MirageOS.example" (Ipaddr.V4.of_string_exn "127.0.0.1") () in
    Logs.set_reporter r ;
    Logs.set_level ~all:true (Some Logs.Debug) ;
    let rec go () =
      Logs_lwt.warn (fun l -> l "foobar") >>= fun () ->
      Logs_lwt.err (fun l -> l "bar foofoobar") >>= fun () ->
      Logs_lwt.info (fun l -> l "foofoobar") >>= fun () ->
      Logs_lwt.debug (fun l -> l "debug foofoobar") >>= fun () ->
      T.sleep 1.0 >>= fun () ->
      go ()
    in
    go ()

  end
