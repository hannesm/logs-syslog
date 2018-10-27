(** Logs reporter via syslog using MirageOS and TLS

    Please read {!Logs_syslog} first. *)

(** TLS reporter *)
module Tls (C : Mirage_console_lwt.S) (CLOCK : Mirage_clock.PCLOCK) (STACK : Mirage_stack_lwt.V4) (KV : Mirage_kv_lwt.RO) : sig

  (** [create c clock tcp kv ~keyname ~hostname ip ~port ~truncate ~framing ()]
      is [Ok reporter] or [Error msg].  Key material (ca-roots.crt, certificate
      chain, private key) are read from [kv] (using [keyname], defaults to
      [server]).  The [reporter] sends log messages to [ip, port] via TLS.  If
      the initial TLS connection to the [remote_ip] fails, an [Error msg] is
      returned instead.  If the TLS connection fails, it is reported to console
      [c], and attempts are made to re-establish the TLS connection.  Each
      message can be truncated (to [truncate] bytes), default is to not
      truncate.  The [hostname] is part of each syslog message.  The [port]
      defaults to 6514, [framing] to appending a zero byte. [facility] is the
      default syslog facility (see {!Logs_syslog.message}).  *)
  val create : C.t -> CLOCK.t -> STACK.t -> KV.t -> ?keyname:string -> hostname:string ->
    STACK.ipv4addr -> ?port:int -> ?truncate:int -> ?framing:Logs_syslog.framing ->
    ?facility:Syslog_message.facility -> unit ->
    (Logs.reporter, string) result STACK.io
end

(** {1:mirage_example Example usage}

    To install a Mirage syslog reporter, sending via TLS to localhost, use the
    following snippet:
{[
open Mirage_types_lwt
module Main (C : CONSOLE) (S : STACKV4) (CLOCK : PCLOCK) (KEYS : KV_RO)
  module TLS  = Tls_mirage.Make(S.TCPV4)
  module X509 = Tls_mirage.X509(KEYS)(CLOCK)

  module LT = Logs_syslog_mirage_tls.Tls(C)(CLOCK)(S)(KEYS)

  let start c s _ kv =
    let ip = Ipaddr.V4.of_string_exn "127.0.0.1" in
    LT.create c s kv ~hostname ip () >>= function
      | Ok r -> Logs.set_reporter r ; Lwt.return_unit
      | Error e -> Lwt.fail_invalid_arg e
end
]}

*)
