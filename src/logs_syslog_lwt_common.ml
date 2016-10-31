open Logs_syslog

let syslog_report_common host now send =
  let report src level ~over k msgf =
    let source = Logs.Src.name src in
    let timestamp = now () in
    let k tags ?header _ =
      let msg =
        message ~host ~source ~tags ?header level timestamp (flush ())
      in
      let bytes = Syslog_message.encode msg in
      let unblock () = over () ; Lwt.return_unit in
      Lwt.finalize (fun () -> send bytes) unblock |> Lwt.ignore_result ; k ()
    in
    msgf @@ fun ?header ?(tags = Logs.Tag.empty) fmt ->
    Format.kfprintf (k tags ?header) ppf fmt
  in
  { Logs.report }

(* concurrent writers over a single fd:
 - we should ensure that write is only called once
 - if fd is dead, only one reconnect should happen at any time
 - queue/ringbuffer/stream events is likely overkill

 - Lwt_mutex and Lwt_condition -- but the latter needs size control (pls no OOM due to too many log messages!)
*)
