open Result

(* TODO: support IPv6 *)
val udp_reporter : string -> Unix.inet_addr -> int -> Logs.reporter

val tcp_reporter : string -> Unix.inet_addr -> int -> (Logs.reporter, string) result
