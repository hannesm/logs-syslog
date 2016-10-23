open Result

val tcp_tls_reporter : string -> Lwt_unix.inet_addr -> int -> cacert:string -> cert:string -> priv_key:string -> (Logs.reporter, string) result Lwt.t
