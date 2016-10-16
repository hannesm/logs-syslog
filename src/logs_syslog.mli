
val message : ?facility:Syslog_message.facility -> host:string -> source:string -> Logs.level -> Ptime.t -> string -> Syslog_message.t

val ppf : Format.formatter

val flush : unit -> string

type connection = [
  | `UDP of Ipaddr.V4.t * int
  | `TCP of Ipaddr.V4.t * int
  | `TLSoTCP of X509.t list * X509.private_key * X509.Authenticator.a * string * int
]
