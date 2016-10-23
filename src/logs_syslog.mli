(** Logs reporter using syslog

    The {{:http://erratique.ch/software/logs/doc/Logs.html}logs} library
    provides basic logging support, each log source has an independent logging
    level, and reporting is decoupled from logging.

    This library implements log reporters via syslog, using
    {{:http://verbosemo.de/syslog-message/}syslog-message}.

    A variety of transport mechanisms are implemented:
    {ul
    {- {{:https://tools.ietf.org/html/rfc3164}RFC 3164} specifies the original
       BSD syslog protocol over UDP on port 514 (also
       {{:https://tools.ietf.org/html/rfc5126}RFC 5126}).}
    {- {{:https://tools.ietf.org/html/rfc6587}RFC 6587} specifies the historic
       syslog over TCP on port 514.}
    {- {{:https://tools.ietf.org/html/rfc5125}RFC 5125} specifies syslog over
       TLS on TCP port 6514.}}

    The UDP transport sends each log message to the remote log host using
    [sendto].  If [sendto] raises an [Unix.Unix_error], this error is printed
    together with the log message on standard error.

    When using a stream transport, TCP or TLS, the creation of a reporter
    attempts to establish a connection to the log host, and only results in [Ok]
    {!Logs.reporter} on success, otherwise the [Error msg] is returned.  At
    runtime when the connection failed, the message is printed on standard
    error, and a re-establishment of the connection is attempted.

    Every time a library logs a message which reaches the reporter (depending on
    log level), the function {!message} is evaluated with the [hostname]
    provided while creating the reporter, the log level is mapped to a syslog
    level, and the current timestamp is added.  The log message is prepended
    with the log source name.

    This module contains the pure fragments shared between the effectful
    implementation for {{!Logs_syslog_unix}Unix}, {{!Logs_syslog_lwt}Lwt}, and
    {{!Logs_syslog_mirage}MirageOS}.  TLS support is available for
    {{!Logs_syslog_lwt_tls}Lwt} and {{!Logs_syslog_mirage_tls}MirageOS}.

    Not implemented is the reliable transport for syslog (see
    {{:https://tools.ietf.org/html/rfc3195}RFC 3195}) (using port 601), which is
    an alternative transport of syslog messages over TCP.

    {e %%VERSION%% - {{:%%PKG_HOMEPAGE%% }homepage}} *)

(** [message ~facility ~host ~source level now msg] is [message], a syslog
    message with the given values.  The default [facility] is
    [Syslog_message.System_Daemons].  *)
val message :
  ?facility:Syslog_message.facility ->
  host:string ->
  source:string ->
  Logs.level ->
  Ptime.t ->
  string ->
  Syslog_message.t

(** [ppf] is a formatter *)
val ppf : Format.formatter

(** [flush ()] flushes the formatter, and return the [text] *)
val flush : unit -> string
