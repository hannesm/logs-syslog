open Logs_syslog

let syslog_report host send =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = Ptime_clock.now () in
    let k _ =
      let message = message ~host ~source level timestamp (flush ()) in
      send (Syslog_message.to_string message) ;
      over () ; k ()
    in
    msgf @@ fun ?header:_h ?tags:_t fmt ->
    Format.kfprintf k ppf fmt
  in
  { Logs.report }

let sock ip port = Unix.(ADDR_INET (inet_addr_of_string (Ipaddr.V4.to_string ip), port))

let unix_syslog_reporter host = function
  | `UDP (ip, port) ->
    let sa = sock ip port in
    let s = Unix.(socket PF_INET SOCK_DGRAM 0) in
    let send msg = ignore(Unix.sendto s (Bytes.of_string msg) 0 (String.length msg) [] sa) in
    syslog_report host send
  | `TCP (ip, port) ->
    let sa = sock ip port in
    let s = Unix.(socket PF_INET SOCK_STREAM 0) in
    Unix.(setsockopt s SO_REUSEADDR true) ;
    Unix.(setsockopt s SO_KEEPALIVE true) ;
    Unix.connect s sa ;
    let send msg = ignore(Unix.send s (Bytes.of_string msg) 0 (String.length msg) []) in
    syslog_report host send
    (* TODO: someone should call close at some point, but program exit does this for us as well ;) *)
  | _ -> invalid_arg "NYI"

(* example code *)
(*
 let _ =
  Logs.set_reporter (unix_syslog_reporter "OCaml" (`TCP (Ipaddr.V4.of_string_exn "127.0.0.1", 5514))) ;
  (*  Logs.set_reporter (unix_syslog_reporter "OCaml" (`UDP (Ipaddr.V4.of_string_exn "127.0.0.1", 514))) ; *)
  Logs.set_level ~all:true (Some Logs.Debug) ;
  Logs.warn (fun l -> l "foobar") ;
  Logs.err (fun l -> l "bar foofoobar") ;
  Logs.info (fun l -> l "foofoobar")
*)
