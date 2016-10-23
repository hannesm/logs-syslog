open Logs_syslog
open Result

let syslog_report host send =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = Ptime_clock.now () in
    let k _ =
      let msg = message ~host ~source level timestamp (flush ()) in
      send (Syslog_message.to_string msg) ;
      over () ; k ()
    in
    msgf @@ fun ?header:_h ?tags:_t fmt ->
    Format.kfprintf k ppf fmt
  in
  { Logs.report }

let udp_reporter ?(hostname = Unix.gethostname ()) ip ?(port = 514) () =
  let sa = Unix.ADDR_INET (ip, port) in
  let s = Unix.(socket PF_INET SOCK_DGRAM 0) in
  let rec send msg =
    try ignore(Unix.sendto s (Bytes.of_string msg) 0 (String.length msg) [] sa) with
    | Unix.Unix_error (Unix.EAGAIN, _, _) -> send msg
    | Unix.Unix_error (e, f, _) ->
      Printf.eprintf "error in %s %s while sending to %s:%d\n%s %s\n"
        f (Unix.error_message e) (Unix.string_of_inet_addr ip) port
        (Ptime.to_rfc3339 (Ptime_clock.now ()))
        msg
  in
  syslog_report hostname send

(* TODO: someone should call close at program exit *)
let tcp_reporter ?(hostname = Unix.gethostname ()) ip ?(port = 514) () =
  let sa = Unix.ADDR_INET (ip, port) in
  let s = ref None in
  let connect () =
    let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
    Unix.(setsockopt sock SO_REUSEADDR true) ;
    Unix.(setsockopt sock SO_KEEPALIVE true) ;
    try
      Unix.connect sock sa ;
      s := Some sock;
      Ok ()
    with
    | Unix.Unix_error (e, f, _) ->
      Error (Printf.sprintf "error %s in function %s while connecting to %s:%d\n"
               (Unix.error_message e) f (Unix.string_of_inet_addr ip) port)
  in
  let reconnect k msg =
    match connect () with
    | Ok () -> k msg
    | Error e -> Printf.eprintf "%s while sending syslog message\n%s %s\n"
                   e (Ptime.to_rfc3339 (Ptime_clock.now ())) msg
  in
  match connect () with
  | Error e -> Error e
  | Ok () ->
    let rec send omsg = match !s with
      | None -> reconnect send omsg
      | Some sock ->
        let msg = Bytes.of_string (omsg ^ "\000") in
        let len = Bytes.length msg in
        let rec aux idx =
          try
            let should = len - idx in
            let n = Unix.send sock msg idx should [] in
            if n = should then () else aux (idx + n)
          with
          | Unix.Unix_error (Unix.EAGAIN, _, _) -> send omsg
          | Unix.Unix_error (e, f, _) ->
            let err = Unix.error_message e in
            Printf.eprintf "error %s in function %s, reconnecting\n" err f ;
            (try Unix.close sock with _ -> ()) ;
            s := None ;
            reconnect send omsg
        in
        aux 0
    in
    Ok (syslog_report hostname send)

(* example code *)
(* let _ =
   let lo = Unix.inet_addr_of_string "127.0.0.1" in
   match tcp_reporter lo with
   | Error e -> print_endline e
   | Ok r -> Logs.set_reporter r ;
     (* Logs.set_reporter (udp_reporter lo) ; *)
     Logs.set_level ~all:true (Some Logs.Debug) ;
     Logs.warn (fun l -> l "foobar") ;
     Logs.err (fun l -> l "bar foofoobar") ;
     Logs.info (fun l -> l "foofoobar") ;
     Logs.debug (fun l -> l "debug foofoobar")
*)
