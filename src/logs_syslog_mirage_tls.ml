module Tls (C : V1_LWT.CONSOLE) (CLOCK : V1.CLOCK) (TCP : V1_LWT.TCPV4) (KV : V1_LWT.KV_RO) = struct
  open Result
  open Lwt.Infix
  open Logs_syslog

  module TLS = Tls_mirage.Make(TCP)
  module X509 = Tls_mirage.X509(KV)(CLOCK)

  let tcp_err_to_string = function
    | `Unknown s -> s
    | `Timeout -> "timeout"
    | `Refused -> "refused"

  let err_to_string = function
    | `Tls_alert a -> Tls.Packet.alert_type_to_string a
    | `Tls_failure f -> Tls.Engine.string_of_failure f
    | `Flow e -> tcp_err_to_string e

  let create c tcp kv ?keyname ~hostname dst ?(port = 6514) ?(framing = `Null) () =
    let f = ref None in
    let dsts =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.V4.to_string dst) port
    in
    let m = Lwt_mutex.create () in
    X509.authenticator kv `CAs >>= fun authenticator ->
    let certname = match keyname with None -> `Default | Some x -> `Name x in
    X509.certificate kv certname >>= fun priv ->
    let certificates = `Single priv in
    let conf = Tls.Config.client ~authenticator ~certificates () in
    let connect () =
      Lwt.catch (fun () ->
          TCP.create_connection tcp (dst, port) >>= function
          | `Error e ->
            let err = Printf.sprintf "error %s %s" (tcp_err_to_string e) dsts in
            Lwt.return (Error err)
          | `Ok flow ->
            TLS.client_of_flow conf "" flow >|= function
            | `Ok tlsflow -> f := Some tlsflow ; Ok ()
            | `Eof -> Error ("EOF " ^ dsts)
            | `Error e -> Error ("error " ^ err_to_string e ^ " " ^ dsts))
        (fun e ->
           let s = Printf.sprintf "exception %s %s"
               (Printexc.to_string e) dsts
           in
           Lwt.return (Error s))
    in
    let reconnect k msg =
      Lwt_mutex.lock m >>= fun () ->
      (match !f with
       | None -> connect ()
       | Some _ -> Lwt.return (Ok ())) >>= function
      | Ok () -> Lwt_mutex.unlock m ; k msg
      | Error e ->
        Lwt_mutex.unlock m ;
        C.log_s c (Printf.sprintf "error %s, message %s" e msg)
    in
    let rec send omsg =
      match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.of_string (frame_message omsg framing) in
        Lwt.catch (fun () ->
            TLS.write flow msg >>= function
            | `Ok () -> Lwt.return_unit
            | `Eof ->
              f := None ;
              C.log_s c ("EOF " ^ dsts ^ ", reconnecting") >>= fun () ->
              reconnect send omsg
            | `Error e ->
              f := None ;
              let msg =
                Printf.sprintf "error %s %s, reconnecting" (err_to_string e) dsts
              in
              C.log_s c msg >>= fun () ->
              reconnect send omsg)
          (fun e ->
             f := None ;
             let msg =
               let exc = Printexc.to_string e in
               Printf.sprintf "exception %s %s, reconnecting" exc dsts
             in
             C.log_s c msg >>= fun () ->
             reconnect send omsg)
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            hostname
            (fun () -> match Ptime.of_float_s (CLOCK.time ()) with
               | Some t -> t
               | None -> invalid_arg "couldn't read time")
            send)
    | Error e -> Error e
end
