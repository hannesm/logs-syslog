(** Logs reporter via syslog using MirageOS

    Please read {!Logs_syslog} first. *)

(** UDP syslog *)
module Udp (C : V1_LWT.CONSOLE) (CLOCK : V1.PCLOCK) (STACK : Mirage_stack_lwt.V4) : sig
  (** [create c clock udp ~hostname ip ~port ~truncate ()] is [reporter], which
      sends log messages to [ip, port] via UDP.  Upon failure, a message is
      emitted to the console [c].  Each message can be truncated: [truncate]
      defaults to 65535 bytes.  The [hostname] is part of each syslog message.
      The [port] defaults to 514. *)
  val create : C.t -> CLOCK.t -> STACK.t -> hostname:string ->
    STACK.ipv4addr -> ?port:int -> ?truncate:int -> unit -> Logs.reporter
end

(** TCP syslog *)
module Tcp (C : V1_LWT.CONSOLE) (CLOCK : V1.PCLOCK) (STACK : V1_LWT.STACKV4) : sig
  (** [create c clock tcp ~hostname ip ~port ~truncate ~framing ()] is [Ok
      reporter] or [Error msg].  The [reporter] sends log messages to [ip, port]
      via TCP.  If the initial TCP connection to the [remote_ip] fails, an
      [Error msg] is returned instead.  If the TCP connection fails, an error is
      logged to the console [c] and attempts are made to re-establish the TCP
      connection.  Each syslog message can be truncated, depending on [truncate]
      (defaults to no truncating).  The [hostname] is part of each syslog
      message.  The default value of [port] is 514, the default behaviour of
      [framing] is to append a 0 byte. *)
  val create : C.t -> CLOCK.t -> STACK.t -> hostname:string ->
    STACK.ipv4addr -> ?port:int ->
    ?truncate:int ->
    ?framing:Logs_syslog.framing -> unit ->
    (Logs.reporter, string) Result.result STACK.io
end

(** {1:mirage_example Example usage}

    To install a Mirage syslog reporter, sending via UDP to localhost, use the
    following snippet:
{[
module Main (C : V1_LWT.CONSOLE) (S : V1_LWT.STACKV4) (CLOCK : V1.CLOCK)
  module LU = Logs_syslog_mirage.Udp(C)(CLOCK)(S)

  let start c s _ =
    let ip = Ipaddr.V4.of_string_exn "127.0.0.1" in
    let r = LU.create c s ip ~hostname:"MirageOS.example" () in
    Logs.set_reporter r ;
    Lwt.return_unit
end
]}

    The TCP transport is very similar:
{[
module Main (C : V1_LWT.CONSOLE) (S : V1_LWT.STACKV4) (CLOCK : V1.CLOCK)
  module LT = Logs_syslog_mirage.Tcp(C)(CLOCK)(S)

  let start c s _ =
    let ip = Ipaddr.V4.of_string_exn "127.0.0.1" in
    LT.create c s ip ~hostname:"MirageOS.example" () >>= function
      | Ok r -> Logs.set_reporter r ; Lwt.return_unit
      | Error e -> Lwt.fail_invalid_arg e
end
]}

*)
