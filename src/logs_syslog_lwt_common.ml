open Logs_syslog

let syslog_report_common host now send =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = now () in
    let k _ =
      let msg = message ~host ~source level timestamp (flush ()) in
      let unblock () = over () ; Lwt.return_unit in
      Lwt.finalize (fun () -> send (Syslog_message.to_string msg)) unblock |> Lwt.ignore_result ;
      k ()
    in
    msgf @@ fun ?header:_h ?tags:_t fmt ->
    Format.kfprintf k ppf fmt
  in
  { Logs.report }
