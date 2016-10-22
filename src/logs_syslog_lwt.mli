open Result

(* TODO: IPv6 *)
val udp_reporter : string -> Ipaddr.V4.t -> int -> Logs.reporter

val tcp_reporter : string -> Ipaddr.V4.t -> int -> (Logs.reporter, string) result Lwt.t

