module Tls (C : V1_LWT.CONSOLE) (CLOCK : V1.PCLOCK) (TCP : V1_LWT.TCPV4) (KV : V1_LWT.KV_RO) = struct
  open Result
  open Lwt.Infix
  open Logs_syslog

  module TLS = Tls_mirage.Make(TCP)
  module X509 = Tls_mirage.X509(KV)(CLOCK)

  let create c clock tcp kv ?keyname ~hostname dst ?(port = 6514) ?(truncate = 0) ?(framing = `Null) () =
    let f = ref None in
    let dsts =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.V4.to_string dst) port
    in
    let m = Lwt_mutex.create () in
    X509.authenticator kv clock `CAs >>= fun authenticator ->
    let certname = match keyname with None -> `Default | Some x -> `Name x in
    X509.certificate kv certname >>= fun priv ->
    let certificates = `Single priv in
    let conf = Tls.Config.client ~authenticator ~certificates () in
    let connect () =
      TCP.create_connection tcp (dst, port) >>= function
      | Error e ->
        TCP.pp_error Format.str_formatter e ;
        let err = Printf.sprintf "error %s %s" (Format.flush_str_formatter ()) dsts in
        Lwt.return (Error err)
      | Ok flow ->
        TLS.client_of_flow conf flow >|= function
        | Ok tlsflow -> f := Some tlsflow ; Ok ()
        | Error e ->
          TLS.pp_write_error Format.str_formatter e ;
          let err = Printf.sprintf "error %s %s" (Format.flush_str_formatter ()) dsts in
          Error err
    in
    let reconnect k msg =
      Lwt_mutex.lock m >>= fun () ->
      (match !f with
       | None -> connect ()
       | Some _ -> Lwt.return (Ok ())) >>= function
      | Ok () -> Lwt_mutex.unlock m ; k msg
      | Error e ->
        Lwt_mutex.unlock m ;
        C.log c (Printf.sprintf "error %s, message %s" e msg)
    in
    let rec send omsg =
      match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.of_string (frame_message omsg framing) in
        TLS.write flow msg >>= function
        | Ok () -> Lwt.return_unit
        | Error e ->
          f := None ;
          TLS.pp_write_error Format.str_formatter e ;
          let err = Printf.sprintf "error %s %s, reconnecting"
              (Format.flush_str_formatter ()) dsts
          in
          C.log c err >>= fun () ->
          reconnect send omsg
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            hostname
            truncate
            (fun () -> Ptime.v (CLOCK.now_d_ps clock))
            send)
    | Error e -> Error e
end
