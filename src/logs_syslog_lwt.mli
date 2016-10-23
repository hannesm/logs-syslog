open Result

(* TODO: IPv6 *)
val udp_reporter : string -> Lwt_unix.inet_addr -> int -> Logs.reporter

val tcp_reporter : string -> Lwt_unix.inet_addr -> int -> (Logs.reporter, string) result Lwt.t

