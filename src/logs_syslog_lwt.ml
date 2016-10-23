open Lwt.Infix
open Result
open Logs_syslog
open Logs_syslog_lwt_common

let udp_reporter host ip port =
  let sa = Lwt_unix.ADDR_INET (ip, port) in
  let s = Lwt_unix.(socket PF_INET SOCK_DGRAM 0) in
  let send msg =
    Lwt.catch
      (fun () -> Lwt_unix.sendto s (Bytes.of_string msg) 0 (String.length msg) [] sa >|= fun _ -> ())
      (function Unix.Unix_error (e, f, _) ->
               Printf.eprintf "error in %s %s while sending to %s:%d log message %s\n"
                 f (Unix.error_message e) (Unix.string_of_inet_addr ip) port msg ;
               Lwt.return_unit)
  in
  syslog_report_common host Ptime_clock.now send

let tcp_reporter host ip port =
  let sa = Lwt_unix.ADDR_INET (ip, port) in
  let s = ref None in
  let connect () =
    let sock = Lwt_unix.(socket PF_INET SOCK_STREAM 0) in
    Lwt_unix.(setsockopt sock SO_REUSEADDR true) ;
    Lwt_unix.(setsockopt sock SO_KEEPALIVE true) ;
    Lwt.catch
      (fun () -> Lwt_unix.connect sock sa >|= fun () -> s := Some sock ; Ok ())
      (function Unix.Unix_error (e, f, _) ->
         Lwt.return (Error (Printf.sprintf "error %s in function %s while connecting %s:%d"
                              (Unix.error_message e) f (Unix.string_of_inet_addr ip) port)))
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
    let rec send omsg = match !s with
      | None -> reconnect send omsg
      | Some sock ->
        let msg = Bytes.of_string (omsg ^ "\000") in
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
    Lwt.return (Ok (syslog_report_common host Ptime_clock.now send))

(* example code *)
(*
let main () =
  let lo = Unix.inet_addr_of_string "127.0.0.1" in
  (*  Logs.set_reporter (udp_reporter "OCaml" lo 514) ; *)
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
