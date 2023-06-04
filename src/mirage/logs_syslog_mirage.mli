(** Logs reporter via syslog using MirageOS

    Please read {!Logs_syslog} first. *)

(** UDP syslog *)
module Udp (CLOCK : Mirage_clock.PCLOCK) (STACK : Tcpip.Stack.V4V6) : sig
  (** [create udp ~hostname ip ~port ~truncate ()] is [reporter], which
      sends log messages to [ip, port] via UDP.  Upon failure, a message is
      emitted via [printf].  Each message can be truncated: [truncate]
      defaults to 65535 bytes.  The [hostname] is part of each syslog message.
      The [port] defaults to 514. [facility] is the default syslog facility (see
      {!Logs_syslog.message}). *)
  val create : STACK.t -> hostname:string ->
    STACK.IP.ipaddr -> ?port:int -> ?truncate:int ->
    ?facility:Syslog_message.facility -> unit -> Logs.reporter
end

(** TCP syslog *)
module Tcp (CLOCK : Mirage_clock.PCLOCK) (STACK : Tcpip.Stack.V4V6) : sig
  (** [create tcp ~hostname ip ~port ~truncate ~framing ()] is
      [Ok reporter] or [Error msg].  The [reporter] sends log messages to [ip, port]
      via TCP.  If the initial TCP connection to the [remote_ip] fails, an
      [Error msg] is returned instead.  If the TCP connection fails, an error is
      logged via [printf], and attempts are made to re-establish the TCP
      connection.  Each syslog message can be truncated, depending on [truncate]
      (defaults to no truncating).  The [hostname] is part of each syslog
      message.  The default value of [port] is 514, the default behaviour of
      [framing] is to append a zero byte. [facility] is the default syslog
      facility (see {!Logs_syslog.message}). *)
  val create : STACK.t -> hostname:string ->
    STACK.IP.ipaddr -> ?port:int ->
    ?truncate:int ->
    ?framing:Logs_syslog.framing ->
    ?facility:Syslog_message.facility -> unit ->
    (Logs.reporter, string) result Lwt.t
end

(** {2:mirage_example Example usage}

    To install a Mirage syslog reporter, sending via UDP to localhost, use the
    following snippet:
{[
module Main (S : Tcpip.Stack.V4V6) (CLOCK : Mirage_clock.PCLOCK)
  module LU = Logs_syslog_mirage.Udp(CLOCK)(S)

  let start s _ =
    let ip = Ipaddr.V4 (Ipaddr.V4.of_string_exn "127.0.0.1") in
    let r = LU.create s ip ~hostname:"MirageOS.example" () in
    Logs.set_reporter r ;
    Lwt.return_unit
end
]}

    The TCP transport is very similar:
{[
module Main (S : Tcpip.Stack.V4V6) (CLOCK : Mirage_clock.PCLOCK)
  module LT = Logs_syslog_mirage.Tcp(CLOCK)(S)

  let start s _ =
    let ip = Ipaddr.V4 (Ipaddr.V4.of_string_exn "127.0.0.1") in
    LT.create s ip ~hostname:"MirageOS.example" () >>= function
      | Ok r -> Logs.set_reporter r ; Lwt.return_unit
      | Error e -> Lwt.fail_invalid_arg e
end
]}

*)
