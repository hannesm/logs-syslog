module Tls (C : V1.CLOCK) (TCP : V1_LWT.TCP) (KV : V1_LWT.KV_RO) = struct
  open Result
  open Lwt.Infix
  open Logs_syslog

  module TLS = Tls_mirage.Make(TCP)
  module X509 = Tls_mirage.X509(KV)(C)

  let create tcp kv ?keyname ~hostname dst ?(port = 6514) ?(framing = `Null) () =
    let f = ref None in
    X509.authenticator kv `CAs >>= fun authenticator ->
    let certname = match keyname with None -> `Default | Some x -> `Name x in
    X509.certificate kv certname >>= fun priv ->
    let certificates = `Single priv in
    let conf = Tls.Config.client ~authenticator ~certificates () in
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
            (fun () -> match Ptime.of_float_s (C.time ()) with
               | Some t -> t
               | None -> invalid_arg "couldn't read time")
            send)
    | Error (`TCP _) -> Error "couldn't connect via TCP to log host"
    | Error (`TLS (`Tls_alert a)) -> Error ("Received alert while connecting to log host via TLS,  " ^ Tls.Packet.alert_type_to_string a)
    | Error (`TLS (`Tls_failure f)) -> Error ("Encountered TLS failure while connecting to log host via TLS,  " ^ Tls.Engine.string_of_failure f)
    | Error (`TLS _) -> Error "Flow error while connecting to log host via TLS"
    | Error _ -> Error "couldn't connect to log host"
end
