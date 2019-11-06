module Tls (CLOCK : Mirage_clock.PCLOCK) (STACK : Mirage_stack.V4) (KV : Mirage_kv.RO) = struct
  open Lwt.Infix
  open Logs_syslog

  module TCP = STACK.TCPV4
  module TLS = Tls_mirage.Make(TCP)
  module X509 = Tls_mirage.X509(KV)(CLOCK)

  let create stack kv ?keyname ~hostname dst ?(port = 6514) ?(truncate = 0) ?(framing = `Null) ?facility () =
    let tcp = STACK.tcpv4 stack in
    let f = ref None in
    let m = Lwt_mutex.create () in
    X509.authenticator kv `CAs >>= fun authenticator ->
    let certname = match keyname with None -> `Default | Some x -> `Name x in
    X509.certificate kv certname >>= fun priv ->
    let certificates = `Single priv in
    let conf = Tls.Config.client ~authenticator ~certificates () in
    let connect () =
      TCP.create_connection tcp (dst, port) >>= function
      | Error e -> Lwt.return (Error (Fmt.to_to_string TCP.pp_error e))
      | Ok flow ->
        TLS.client_of_flow conf flow >|= function
        | Ok tlsflow -> f := Some tlsflow ; Ok ()
        | Error e -> Error (Fmt.to_to_string TLS.pp_write_error e)
    in
    let reconnect k msg =
      Lwt_mutex.lock m >>= fun () ->
      (match !f with
       | None -> connect ()
       | Some _ -> Lwt.return (Ok ())) >>= function
      | Ok () -> Lwt_mutex.unlock m; k msg
      | Error e ->
        Lwt_mutex.unlock m;
        Printf.printf "syslog-tls error %s, message %s\n%!" e msg;
        Lwt.return_unit
    in
    let rec send omsg =
      match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.of_string (frame_message omsg framing) in
        TLS.write flow msg >>= function
        | Ok () -> Lwt.return_unit
        | Error e ->
          f := None;
          Format.printf "syslog-tls error %a sending message %s\n%!"
            TLS.pp_write_error e omsg;
          reconnect send omsg
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_mirage__Logs_syslog_lwt_common.syslog_report_common
            facility
            hostname
            truncate
            (fun () -> Ptime.v (CLOCK.now_d_ps ()))
            send
            Syslog_message.encode)
    | Error e -> Error e
end
