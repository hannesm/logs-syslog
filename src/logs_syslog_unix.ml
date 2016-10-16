open Logs_syslog

let syslog_report send host =
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

let unix_syslog_reporter host = function
  | `UDP (ip, port) ->
    let sockaddr = Unix.(ADDR_INET (inet_addr_of_string (Ipaddr.V4.to_string ip), port)) in
    let socket = Unix.(socket PF_INET SOCK_DGRAM 0) in
    let send msg = ignore(Unix.sendto socket (Bytes.of_string msg) 0 (String.length msg) [] sockaddr) in
    syslog_report send host
  | _ -> invalid_arg "NYI"

(* example code *)
(*
 let _ =
  Logs.set_reporter (unix_syslog_reporter "OCaml" (`UDP (Ipaddr.V4.of_string_exn "127.0.0.1", 514))) ;
  Logs.warn (fun l -> l "foobar")
*)
