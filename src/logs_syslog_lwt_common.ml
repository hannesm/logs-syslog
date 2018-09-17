open Logs_syslog

let syslog_report_common
    facility
    host
    len
    now
    send
    (encode : ?len:int -> Syslog_message.t -> string) =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = now () in
    let k tags ?header _ =
      let facility = match Logs.Tag.find Logs_syslog.facility tags with
      | None -> facility
      | facility -> facility
      in
      let msg =
        message ?facility ~host ~source ~tags ?header level timestamp (flush ())
      in
      let bytes = encode ~len msg in
      let unblock () = over () ; Lwt.return_unit in
      Lwt.finalize (fun () -> send bytes) unblock |> Lwt.ignore_result ; k ()
    in
    msgf @@ fun ?header ?(tags = Logs.Tag.empty) fmt ->
    Format.kfprintf (k tags ?header) ppf fmt
  in
  { Logs.report }
