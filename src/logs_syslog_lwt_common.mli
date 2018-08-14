val syslog_report_common :
  Syslog_message.facility option -> string -> int -> (unit -> Ptime.t) ->
  (string -> unit Lwt.t) -> Logs.reporter
