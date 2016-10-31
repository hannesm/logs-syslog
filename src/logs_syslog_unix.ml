open Logs_syslog
open Result

let syslog_report host send =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = Ptime_clock.now () in
    let k tags ?header _ =
      let msg =
        message ~host ~source ~tags ?header level timestamp (flush ())
      in
      send (Syslog_message.encode msg) ; over () ; k ()
    in
    msgf @@ fun ?header ?(tags = Logs.Tag.empty) fmt ->
    Format.kfprintf (k tags ?header) ppf fmt
  in
  { Logs.report }

let udp_reporter ?(hostname = Unix.gethostname ()) ip ?(port = 514) () =
  let sa = Unix.ADDR_INET (ip, port) in
  let s = Unix.(socket PF_INET SOCK_DGRAM 0) in
  let rec send msg =
    let b = Bytes.of_string msg in
    try ignore(Unix.sendto s b 0 (String.length msg) [] sa) with
    | Unix.Unix_error (Unix.EAGAIN, _, _) -> send msg
    | Unix.Unix_error (e, f, _) ->
      Printf.eprintf "error in %s %s while sending to %s:%d\n%s %s\n"
        f (Unix.error_message e) (Unix.string_of_inet_addr ip) port
        (Ptime.to_rfc3339 (Ptime_clock.now ()))
        msg
  in
  syslog_report hostname send

type state =
  | Disconnected
  | Connecting
  | Connected of Unix.file_descr

let wait_time = 1

(* TODO: should call close at program exit *)
(* TODO: mutable state s is not locked during updates, there may be races! *)
let tcp_reporter
    ?(hostname = Unix.gethostname ()) ip ?(port = 514) ?(framing = `Null) () =
  let sa = Unix.ADDR_INET (ip, port) in
  let s = ref Disconnected in
  let connect () =
    let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
    Unix.(setsockopt sock SO_REUSEADDR true) ;
    Unix.(setsockopt sock SO_KEEPALIVE true) ;
    try
      Unix.connect sock sa ;
      s := Connected sock;
      Ok ()
    with
    | Unix.Unix_error (e, f, _) ->
      let err =
        Printf.sprintf "error %s in function %s while connecting to %s:%d\n"
          (Unix.error_message e) f (Unix.string_of_inet_addr ip) port
      in
      Error err
  in
  let reconnect k msg =
    s := Connecting ;
    match connect () with
    | Ok () -> k msg
    | Error e -> Printf.eprintf "%s while sending syslog message\n%s %s\n"
                   e (Ptime.to_rfc3339 (Ptime_clock.now ())) msg
  in
  match connect () with
  | Error e -> Error e
  | Ok () ->
    let rec send omsg = match !s with
      | Disconnected -> reconnect send omsg
      | Connecting -> Unix.sleep wait_time ; send omsg
      | Connected sock ->
        let msg = Bytes.of_string (frame_message omsg framing) in
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
            (try Unix.close sock with Unix.Unix_error _ -> ()) ;
            s := Disconnected ;
            reconnect send omsg
        in
        aux 0
    in
    Ok (syslog_report hostname send)
