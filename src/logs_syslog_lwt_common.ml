open Logs_syslog

let syslog_report_common host len now send =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = now () in
    let k tags ?header _ =
      let msg =
        message ~host ~source ~tags ?header level timestamp (flush ())
      in
      let bytes = Syslog_message.encode ~len msg in
      let unblock () = over () ; Lwt.return_unit in
      Lwt.finalize (fun () -> send bytes) unblock |> Lwt.ignore_result ; k ()
    in
    msgf @@ fun ?header ?(tags = Logs.Tag.empty) fmt ->
    Format.kfprintf (k tags ?header) ppf fmt
  in
  { Logs.report }
