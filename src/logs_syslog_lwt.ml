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
      Lwt.finalize (send (Bytes.of_string (Syslog_message.to_string msg))) unblock |> Lwt.ignore_result ;
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
      (fun () -> Lwt_unix.sendto s msg 0 (Bytes.length msg) [] sa >|= fun _ -> ())
      (function Unix.Unix_error (e, f, _) ->
               let msg = Bytes.to_string msg in
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
      Printf.eprintf "%s while sending log message %s\n" e (Bytes.to_string msg) ;
      Lwt.return_unit
  in
  connect () >>= function
  | Error e -> Lwt.return (Error e)
  | Ok () ->
    let rec send msg () = match !s with
      | None -> reconnect send msg
      | Some sock ->
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
               reconnect send msg)
        in
        aux 0
    in
    Lwt.return (Ok (syslog_report host send))

(* example code *)
(*
let main () =
  let lo = Ipaddr.V4.of_string_exn "127.0.0.1" in
  (*  Logs.set_reporter (udp_reporter "OCaml" lo 514) ; *)
  tcp_reporter "OCaml" lo 5514 >>= function
  | Error e -> print_endline e ; Lwt.return_unit
  | Ok r ->
    Logs.set_reporter r ;
    Logs.set_level ~all:true (Some Logs.Debug) ;
    Logs_lwt.warn (fun l -> l "foobar") >>= fun () ->
    Logs_lwt.err (fun l -> l "bar foofoobar") >>= fun () ->
    Logs_lwt.info (fun l -> l "foofoobar") >>= fun () ->
    Logs_lwt.debug (fun l -> l "debug foofoobar")

let _ = Lwt_main.run (main ())
*)
