(** Logs reporter via syslog using Unix

    Please read {!Logs_syslog} first. *)

(** [udp_reporter ~hostname remote_ip ~port ()] is [reporter], which sends log
    message to [remote_ip, port] via UDP.  The [hostname] is part of each syslog
    message, and defaults to [Unix.gethostname ()], the [port] defaults to
    514. *)
val udp_reporter : ?hostname:string -> Unix.inet_addr -> ?port:int -> unit ->
  Logs.reporter

(** [tcp_reporter ~hostname remote_ip ~port ~framing ()] is [Ok reporter] or
    [Error msg].  The [reporter] sends each log message via syslog to
    [remote_ip, port] via TCP.  If the initial TCP connection to the [remote_ip]
    fails, an [Error msg] is returned instead.  If the TCP connection fails, the
    log message is reported to standard error, and attempts are made to
    re-establish the TCP connection.  Each syslog message is terminated with a 0
    byte.  The [hostname] defaults to [Unix.gethostname ()], [port] to 514,
    [framing] to append a 0 byte. *)
val tcp_reporter : ?hostname:string -> Unix.inet_addr -> ?port:int -> ?framing:Logs_syslog.framing -> unit ->
  (Logs.reporter, string) Result.result

(** {1:unix_example Example usage}

    To install a Unix syslog reporter. sending via UDP to localhost, use the
    following snippet:

{[
Logs.set_reporter (udp_reporter (Unix.inet_addr_of_string "127.0.0.1") ())
]}

    To install a reporter using TCP, use the following snippet:
{[
let () =
  match tcp_reporter (Unix.inet_addr_of_string "127.0.0.1") () with
  | Error e -> print_endline e
  | Ok r -> Logs.set_reporter r
]}

*)
