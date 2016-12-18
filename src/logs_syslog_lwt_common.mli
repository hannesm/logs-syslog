val syslog_report_common :
  string -> int -> (unit -> Ptime.t) -> (string -> unit Lwt.t) -> Logs.reporter
