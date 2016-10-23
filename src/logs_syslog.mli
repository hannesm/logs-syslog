
val message : ?facility:Syslog_message.facility -> host:string -> source:string -> Logs.level -> Ptime.t -> string -> Syslog_message.t

val ppf : Format.formatter

val flush : unit -> string
