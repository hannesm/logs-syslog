open Result

val tcp_tls_reporter : string -> Ipaddr.V4.t -> int -> cacert:string -> cert:string -> priv_key:string -> (Logs.reporter, string) result Lwt.t
