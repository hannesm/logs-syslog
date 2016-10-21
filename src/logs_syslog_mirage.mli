
module Udp (C : V1.PCLOCK) (UDP : V1_LWT.UDP) : sig
  val create : C.t -> UDP.t -> string -> UDP.ipaddr -> int -> Logs.reporter
end
