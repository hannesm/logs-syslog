open Result

(* TODO: support IPv6 *)
val udp_syslog_reporter : string -> Ipaddr.V4.t -> int -> Logs.reporter

val tcp_syslog_reporter : string -> Ipaddr.V4.t -> int -> (Logs.reporter, string) result
