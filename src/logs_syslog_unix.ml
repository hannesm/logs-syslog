open Logs_syslog

let syslog_report src level ~over k msgf =
  let source = Logs.Src.name src in
  let timestamp = Ptime_clock.now () in
  let k _ =
    let message = message ~host:"my2host" ~source level timestamp (flush ()) in
    print_endline (Syslog_message.to_string message) ;
    over () ; k ()
  in
  msgf @@ fun ?header:_h ?tags:_t fmt ->
  Format.kfprintf k ppf fmt

let unix_syslog_reporter () = { Logs.report = syslog_report }

let _ =
  Logs.set_reporter (unix_syslog_reporter ()) ;
  Logs.warn (fun l -> l "foobar")
