(** Logs reporter via syslog using MirageOS

    Please read {!Logs_syslog} first. *)

(** UDP syslog *)
module Udp (C : V1.CLOCK) (UDP : V1_LWT.UDP) : sig

  (* XXX: on failure (currently there is no failure), use a console! *)
  (** [create udp ~hostname ip ~port ()] is [reporter], which sends log
      messages to [ip, port] via UDP.  The [hostname] is part of each syslog
      message.  The [port] defaults to 514. *)
  val create : UDP.t -> hostname:string -> UDP.ipaddr -> ?port:int -> unit ->
    Logs.reporter
end

(** TCP syslog *)
module Tcp (C : V1.CLOCK) (TCP : V1_LWT.TCP) : sig

  (* XXX: on failure (currently there is no failure), use a console! *)
  (** [create tcp ~hostname ip ~port ()] is [Ok reporter] or [Error msg].
      The [reporter] sends log messages to [ip, port] via TCP.  If the initial
      TCP connection to the [remote_ip] fails, an [Error msg] is returned
      instead.  If the TCP connection fails, attempts are made to re-establish
      the TCP connection.  The [hostname] is part of each syslog message.  The
      default value of [port] is 514, the default behaviour of [framing] is to
      append a 0 byte. *)
  val create : TCP.t -> hostname:string -> TCP.ipaddr -> ?port:int ->
    ?framing:Logs_syslog.framing -> unit ->
    (Logs.reporter, string) Result.result TCP.io
end

(** {1:mirage_example Example usage}

    To install a Mirage syslog reporter, sending via UDP to localhost, use the
    following snippet:
{[
module Main (S:V1_LWT.STACKV4) (C:V1.CLOCK)
  module LU = Logs_syslog_mirage.Udp(C)(S.UDPV4)

  let start s _ =
    let ip = Ipaddr.V4.of_string_exn "127.0.0.1" in
    let r = LU.create (S.udpv4 s) ip ~hostname:"MirageOS.example" () in
    Logs.set_reporter r ;
    Lwt.return_unit
end
]}

    The TCP transport is very similar:
{[
module Main (S:V1_LWT.STACKV4) (C:V1.CLOCK)
  module LT = Logs_syslog_mirage.Tcp(C)(S.TCPV4)

  let start s _ =
    let ip = Ipaddr.V4.of_string_exn "127.0.0.1" in
    LT.create (S.tcpv4 s) ip ~hostname:"MirageOS.example" () >>= function
      | Ok r -> Logs.set_reporter r ; Lwt.return_unit
      | Error e -> Lwt.fail_invalid_arg e
end
]}

*)
