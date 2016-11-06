(** Logs reporter via syslog using MirageOS and TLS

    Please read {!Logs_syslog} first. *)

(** TLS reporter *)
module Tls (C : V1_LWT.CONSOLE) (CLOCK : V1.PCLOCK) (TCP : V1_LWT.TCPV4) (KV : V1_LWT.KV_RO) : sig

  (** [create c clock tcp kv ~keyname ~hostname ip ~port ~framing ()] is [Ok
      reporter] or [Error msg].  Key material (ca-roots.crt, certificate chain,
      private key) are read from [kv] (using [keyname], defaults to [server]).
      The [reporter] sends log messages to [ip, port] via TLS.  If the initial
      TLS connection to the [remote_ip] fails, an [Error msg] is returned
      instead.  If the TLS connection fails, it is reported to console [c], and
      attempts are made to re-establish the TLS connection.  The [hostname] is
      part of each syslog message.  The [port] defaults to 6514, [framing] to
      appending a 0 byte.  *)
  val create : C.t -> CLOCK.t -> TCP.t -> KV.t -> ?keyname:string -> hostname:string ->
    TCP.ipaddr -> ?port:int -> ?framing:Logs_syslog.framing -> unit ->
    (Logs.reporter, string) Result.result TCP.io
end

(** {1:mirage_example Example usage}

    To install a Mirage syslog reporter, sending via TLS to localhost, use the
    following snippet:
{[
module Main (C : V1_LWT.CONSOLE) (S : V1_LWT.STACKV4) (CLOCK : V1.CLOCK) (KEYS : V1_LWT.KV_RO)
  module TLS  = Tls_mirage.Make(S.TCPV4)
  module X509 = Tls_mirage.X509(KEYS)(CLOCK)

  module LT = Logs_syslog_mirage_tls.Tls(C)(CLOCK)(S.TCPV4)(KEYS)

  let start c s _ kv =
    let ip = Ipaddr.V4.of_string_exn "127.0.0.1" in
    LT.create c (S.tcpv4 s) kv ~hostname ip () >>= function
      | Ok r -> Logs.set_reporter r ; Lwt.return_unit
      | Error e -> Lwt.fail_invalid_arg e
end
]}

*)
