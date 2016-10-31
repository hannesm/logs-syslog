(** Logs reporter via syslog using Lwt and TLS

    Please read {!Logs_syslog} first. *)

(** [tcp_tls_reporter ~hostname remote_ip ~port ~cacert ~cn ~cert ~priv_key
    ~framing ()] is [Ok reporter] or [Error msg].  The TLS connection validates
    that [cn] is the common name of the certificate of the log server, it must
    be signed by [cacert].  The reporters credentials are its public [cert], and
    its [priv_key].  The [reporter] sends each log message to [remote_ip, port]
    via TLS.  If the initial TLS connection to the [remote_ip] fails, an [Error
    msg] is returned instead.  If the TLS connection fails, the log message is
    reported to standard error, and an attempt is made to re-establish the TLS
    connection.  Each message is prepended by its length, encoded as decimal
    integer, as specified in {{:https://tools.ietf.org/html/rfc5125}RFC 5125}.
    The default value for [hostname] is [Lwt_unix.gethostname ()], the default
    value for [port] is 6514, [framing] appends a 0 byte by default. *)
val tcp_tls_reporter : ?hostname:string -> Lwt_unix.inet_addr -> ?port:int ->
  cacert:string -> cn:string -> cert:string -> priv_key:string ->
  ?framing:Logs_syslog.framing -> unit ->
  (Logs.reporter, string) Result.result Lwt.t

(** {1:lwt_tls_example Example usage}

    To install a Lwt syslog reporter, sending via TLS to localhost, use the
    following snippet (assuming you already have certificates, and the common
    name of the collector is "log server"):
{[
let install_logger () =
  tls_reporter (Unix.inet_addr_of_string "127.0.0.1")
    ~cacert:"ca.pem" ~cn:"log server" ~cert:"log.pem" ~priv_key:"log.key"
    () >|= function
  | Ok r -> Logs.set_reporter r
  | Error e -> print_endline e

let _ = Lwt_main.run (install_logger ())
]}

*)
