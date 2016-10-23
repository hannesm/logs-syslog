module Tls (C : V1.PCLOCK) (TCP : V1_LWT.TCP) (KV : V1_LWT.KV_RO) = struct
  open Result
  open Lwt.Infix
  open Logs_syslog

  module TLS = Tls_mirage.Make(TCP)
  module X509 = Tls_mirage.X509(KV)(C)

  let create clock tcp kv ~hostname dst ?(port = 6514) ?(framing = `Count) () =
    let f = ref None in
    X509.authenticator kv clock `CAs >>= fun authenticator ->
    X509.certificate kv `Default >>= fun priv ->
    let conf = Tls.Config.client ~authenticator ~certificates:(`Single priv) () in
    let connect () =
      TCP.create_connection tcp (dst, port) >>= function
      | `Error e -> Lwt.return (Error (`TCP e))
      | `Ok flow ->
        TLS.client_of_flow conf "" flow >|= function
        | `Ok tlsflow -> f := Some tlsflow ; Ok ()
        | `Eof -> Error `Eof
        | `Error e -> Error (`TLS e)
    in
    let reconnect k msg =
      connect () >>= function
      | Ok () -> k msg
      | Error _ -> (* print me! *) Lwt.return_unit
    in
    let rec send omsg = match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.of_string (frame_message omsg framing) in
        TLS.write flow msg >>= function
        | `Ok () -> Lwt.return_unit
        | `Eof | `Error _ -> f := None ; reconnect send omsg
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            hostname
            (fun () -> Ptime.v (C.now_d_ps clock))
            send)
    | Error (`TCP _) -> Error "couldn't connect via TCP to log host"
    | Error (`TLS _) -> Error "couldn't connect via TLS to log host"
    | Error _ -> Error "couldn't connect to log host"
end
