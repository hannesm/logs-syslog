
(* TODO: support v6 *)
val unix_syslog_reporter :
  string ->
  [ `TCP of Ipaddr.V4.t * int | `UDP of Ipaddr.V4.t * int ] ->
  Logs.reporter
