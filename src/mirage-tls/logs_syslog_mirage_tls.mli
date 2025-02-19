(** Logs reporter via syslog using MirageOS and TLS

    Please read {!Logs_syslog} first. *)

(** TLS reporter *)
module Tls (STACK : Tcpip.Stack.V4V6) (KV : Mirage_kv.RO) : sig

  (** [create tcp kv ~keyname ~hostname ip ~port ~truncate ~framing ()]
      is [Ok reporter] or [Error msg].  Key material (ca-roots.crt, certificate
      chain, private key) are read from [kv] (using [keyname], defaults to
      [server]).  The [reporter] sends log messages to [ip, port] via TLS.  If
      the initial TLS connection to the [remote_ip] fails, an [Error msg] is
      returned instead. If the TLS connection fails, it is reported via [printf],
      and attempts are made to re-establish the TLS connection.  Each
      message can be truncated (to [truncate] bytes), default is to not
      truncate.  The [hostname] is part of each syslog message.  The [port]
      defaults to 6514, [framing] to appending a zero byte. [facility] is the
      default syslog facility (see {!Logs_syslog.message}).  *)
  val create : STACK.t -> KV.t -> ?keyname:string -> hostname:string ->
    STACK.IP.ipaddr -> ?port:int -> ?truncate:int -> ?framing:Logs_syslog.framing ->
    ?facility:Syslog_message.facility -> unit ->
    (Logs.reporter, string) result Lwt.t
end

(** {2:mirage_example Example usage}

    To install a Mirage syslog reporter, sending via TLS to localhost, use the
    following snippet:
{[
module Main (S : Tcpip.Stack.V4V6) (KEYS : Mirage_kv.RO)
  module TLS  = Tls_mirage.Make(S.TCP)
  module X509 = Tls_mirage.X509(KEYS)

  module LT = Logs_syslog_mirage_tls.Tls(S)(KEYS)

  let start s _ kv =
    let ip = Ipaddr.V4 (Ipaddr.V4.of_string_exn "127.0.0.1") in
    LT.create s kv ~hostname ip () >>= function
      | Ok r -> Logs.set_reporter r ; Lwt.return_unit
      | Error e -> Lwt.fail_invalid_arg e
end
]}

*)
