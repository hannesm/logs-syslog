open Lwt.Infix
open Result
open Logs_syslog
open Logs_syslog_lwt_common

let tcp_tls_reporter host ip port ~cacert ~cert ~priv_key =
  let sa = Lwt_unix.ADDR_INET (ip, port) in
  let tls = ref None in
  X509_lwt.private_of_pems ~cert ~priv_key >>= fun priv ->
  X509_lwt.authenticator (`Ca_file cacert) >>= fun authenticator ->
  let conf = Tls.Config.client ~authenticator ~certificates:(`Single priv) () in
  let connect () =
    let sock = Lwt_unix.(socket PF_INET SOCK_STREAM 0) in
    Lwt_unix.(setsockopt sock SO_REUSEADDR true) ;
    Lwt_unix.(setsockopt sock SO_KEEPALIVE true) ;
    Lwt.catch
      (fun () ->
         Lwt_unix.connect sock sa >>= fun () ->
         Tls_lwt.Unix.client_of_fd conf sock >|= fun t ->
         tls := Some t ;
         Ok ())
      (fun exn ->
         Lwt.return @@ match exn with
         | Unix.Unix_error (e, f, _) ->
           Error (Printf.sprintf "error %s in function %s while connecting %s:%d"
                    (Unix.error_message e) f (Unix.string_of_inet_addr ip) port)
         | Tls_lwt.Tls_failure f ->
           Error (Printf.sprintf "TLS %s" (Tls.Engine.string_of_failure f)))
  in
  let reconnect k msg =
    connect () >>= function
    | Ok () -> k msg
    | Error e ->
      Printf.eprintf "%s while sending log message %s\n" e msg ;
      Lwt.return_unit
  in
  connect () >>= function
  | Error e -> Lwt.return (Error e)
  | Ok () ->
    let rec send omsg = match !tls with
      | None -> reconnect send omsg
      | Some t ->
        let msg = Cstruct.of_string (Printf.sprintf "%d %s" (String.length omsg) omsg) in
        Lwt.catch
          (fun () -> Tls_lwt.Unix.write t msg)
          (fun exn -> (match exn with
               | Unix.Unix_error (e, f, _) ->
                 let err = Unix.error_message e in
                 Printf.eprintf "error %s in function %s, reconnecting\n" err f ;
               | Tls_lwt.Tls_failure f ->
                 Printf.eprintf "TLS error %s" (Tls.Engine.string_of_failure f)) ;
             tls := None ;
             reconnect send omsg)
    in
    Lwt.return (Ok (syslog_report_common host Ptime_clock.now send))

(*
let main () =
  let lo = Unix.inet_addr_of_string "127.0.0.1" in
  tcp_tls_reporter "OCaml" lo 6514 ~cacert:"cacert.pem" ~cert:"client.pem" ~priv_key:"client.key"
  >>= function
  | Error e -> print_endline e ; Lwt.return_unit
  | Ok r -> Logs.set_reporter r ;

    Logs.set_level ~all:true (Some Logs.Debug) ;
    Logs_lwt.warn (fun l -> l "foobar") >>= fun () ->
    Logs_lwt.err (fun l -> l "bar foofoobar") >>= fun () ->
    Logs_lwt.info (fun l -> l "foofoobar") >>= fun () ->
    Logs_lwt.debug (fun l -> l "debug foofoobar")

let _ = Lwt_main.run (main ())
*)
