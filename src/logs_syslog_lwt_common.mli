val syslog_report_common : string -> (unit -> Ptime.t) -> (string -> unit Lwt.t) -> Logs.reporter
