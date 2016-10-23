(** Logs reporter via syslog using MirageOS

    Please read {!Logs_syslog} first. *)

(** UDP syslog *)
module Udp (C : V1.PCLOCK) (UDP : V1_LWT.UDP) : sig

  (* XXX: on failure (currently there is no failure), use a console! *)
  (** [create clock udp ~hostname ip ~port ()] is [reporter], which sends log
      messages to [ip, port] via UDP.  The [hostname] is part of each syslog
      message.  The [port] defaults to 514. *)
  val create : C.t -> UDP.t -> hostname:string -> UDP.ipaddr -> ?port:int -> unit ->
    Logs.reporter
end

(** TCP syslog *)
module Tcp (C : V1.PCLOCK) (TCP : V1_LWT.TCP) : sig

  (* XXX: on failure (currently there is no failure), use a console! *)
  (** [create clock tcp ~hostname ip ~port ()] is [Ok reporter] or [Error msg].
      The [reporter] sends log messages to [ip, port] via TCP.  If the initial
      TCP connection to the [remote_ip] fails, an [Error msg] is returned
      instead.  If the TCP connection fails, attempts are made to re-establish
      the TCP connection.  The [hostname] is part of each syslog message.  The
      [port] defaults to 514, [framing] to append a 0 byte. *)
  val create : C.t -> TCP.t -> hostname:string -> TCP.ipaddr -> ?port:int -> ?framing:Logs_syslog.framing -> unit ->
    (Logs.reporter, string) Result.result TCP.io
end
