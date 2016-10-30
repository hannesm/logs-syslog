(** Logs reporter via syslog using MirageOS and TLS

    Please read {!Logs_syslog} first. *)

(* could use a FLOW instead, but then the reconnect logic would need to be elsewhere... *)

(** TLS reporter *)
module Tls (C : V1.CLOCK) (TCP : V1_LWT.TCP) (KV : V1_LWT.KV_RO) : sig

  (** [create clock tcp kv ~keyname ~hostname ip ~port ~framing ()] is [Ok
      reporter] or [Error msg].  Key material (ca-roots.crt, certificate chain,
      private key) are read from [kv] (using [keyname], defaults to [server]).
      The [reporter] sends log messages to [ip, port] via TLS.  If the initial
      TLS connection to the [remote_ip] fails, an [Error msg] is returned
      instead.  If the TLS connection fails, attempts are made to re-establish
      the TLS connection.  The [hostname] is part of each syslog message.  The
      [port] defaults to 6514, [framing] to appending a 0 byte.  *)
  val create : TCP.t -> KV.t -> ?keyname:string -> hostname:string ->
    TCP.ipaddr -> ?port:int -> ?framing:Logs_syslog.framing -> unit ->
    (Logs.reporter, string) Result.result TCP.io
end
