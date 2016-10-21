open Logs_syslog
open Lwt.Infix
open Result

let syslog_report host send =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = Ptime_clock.now () in
    let k _ =
      let msg = message ~host ~source level timestamp (flush ()) in
      let unblock () = over () ; Lwt.return_unit in
      Lwt.finalize (send (Syslog_message.to_string msg)) unblock |> Lwt.ignore_result ;
      k ()
    in
    msgf @@ fun ?header:_h ?tags:_t fmt ->
    Format.kfprintf k ppf fmt
  in
  { Logs.report }

let sock ip port = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string (Ipaddr.V4.to_string ip), port)

let udp_reporter host ip port =
  let sa = sock ip port in
  let s = Lwt_unix.(socket PF_INET SOCK_DGRAM 0) in
  let send msg () =
    Lwt.catch
      (fun () -> Lwt_unix.sendto s (Bytes.of_string msg) 0 (String.length msg) [] sa >|= fun _ -> ())
      (function Unix.Unix_error (e, f, _) ->
               Printf.eprintf "error in %s %s while sending to %s:%d log message %s\n"
                 f (Unix.error_message e) (Ipaddr.V4.to_string ip) port msg ;
               Lwt.return_unit)
  in
  syslog_report host send

let tcp_reporter host ip port =
  let sa = sock ip port in
  let s = ref None in
  let connect () =
    let sock = Lwt_unix.(socket PF_INET SOCK_STREAM 0) in
    Lwt_unix.(setsockopt sock SO_REUSEADDR true) ;
    Lwt_unix.(setsockopt sock SO_KEEPALIVE true) ;
    Lwt.catch
      (fun () -> Lwt_unix.connect sock sa >|= fun () -> s := Some sock ; Ok ())
      (function Unix.Unix_error (e, f, _) ->
         Lwt.return (Error (Printf.sprintf "error %s in function %s while connecting %s:%d"
                              (Unix.error_message e) f (Ipaddr.V4.to_string ip) port)))
  in
  let reconnect k msg =
    connect () >>= function
    | Ok () -> k msg ()
    | Error e ->
      Printf.eprintf "%s while sending log message %s\n" e msg ;
      Lwt.return_unit
  in
  connect () >>= function
  | Error e -> Lwt.return (Error e)
  | Ok () ->
    let rec send omsg () = match !s with
      | None -> reconnect send omsg
      | Some sock ->
        let msg = Bytes.of_string (omsg ^ "\n") in
        let len = Bytes.length msg in
        let rec aux idx =
          Lwt.catch (fun () ->
              let should = len - idx in
              Lwt_unix.send sock msg idx (len - idx) [] >>= fun n ->
              if n = should then Lwt.return_unit else aux (idx + n))
            (function Unix.Unix_error (e, f, _) ->
               let err = Unix.error_message e in
               Printf.eprintf "error %s in function %s, reconnecting\n" err f ;
               s := None ;
               reconnect send omsg)
        in
        aux 0
    in
    Lwt.return (Ok (syslog_report host send))

let tcp_tls_reporter host ip port ~cacert ~cert ~priv_key =
  let sa = sock ip port in
  let tls = ref None in
  X509_lwt.private_of_pems ~cert ~priv_key >>= fun priv ->
  X509_lwt.authenticator (`Ca_file cacert) >>= fun authenticator ->
  let connect () =
    let sock = Lwt_unix.(socket PF_INET SOCK_STREAM 0) in
    Lwt_unix.(setsockopt sock SO_REUSEADDR true) ;
    Lwt_unix.(setsockopt sock SO_KEEPALIVE true) ;
    Lwt.catch
      (fun () ->
         Lwt_unix.connect sock sa >>= fun () ->
         let conf =
           Tls.Config.client ~authenticator ~certificates:(`Single priv) ()
         in
         Tls_lwt.Unix.client_of_fd conf sock >|= fun t ->
         tls := Some t ;
         Ok ())
      (fun exn ->
         Lwt.return @@ match exn with
         | Unix.Unix_error (e, f, _) ->
           Error (Printf.sprintf "error %s in function %s while connecting %s:%d"
                    (Unix.error_message e) f (Ipaddr.V4.to_string ip) port)
         | Tls_lwt.Tls_failure f ->
           Error (Printf.sprintf "TLS %s" (Tls.Engine.string_of_failure f)))
  in
  let reconnect k msg =
    connect () >>= function
    | Ok () -> k msg ()
    | Error e ->
      Printf.eprintf "%s while sending log message %s\n" e msg ;
      Lwt.return_unit
  in
  connect () >>= function
  | Error e -> Lwt.return (Error e)
  | Ok () ->
    let rec send omsg () = match !tls with
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
    Lwt.return (Ok (syslog_report host send))

(* example code *)
(*
let main () =
  let lo = Ipaddr.V4.of_string_exn "127.0.0.1" in
  (*  Logs.set_reporter (udp_reporter "OCaml" lo 514) ; *)
  (* tcp_tls_reporter "OCaml" lo 5514 ~cacert:"cacert.pem" ~cert:"client.pem" ~priv_key:"client.key" *)
  (*  tcp_reporter "OCaml" lo 5514  *)
(* >>= function
  | Error e -> print_endline e ; Lwt.return_unit
  | Ok r -> Logs.set_reporter r ; *)

    Logs.set_level ~all:true (Some Logs.Debug) ;
    Logs_lwt.warn (fun l -> l "foobar") >>= fun () ->
    Logs_lwt.err (fun l -> l "bar foofoobar") >>= fun () ->
    Logs_lwt.info (fun l -> l "foofoobar") >>= fun () ->
    Logs_lwt.debug (fun l -> l "debug foofoobar")

let _ = Lwt_main.run (main ())
*)
