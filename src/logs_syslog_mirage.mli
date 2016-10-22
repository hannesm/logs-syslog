
module Udp (C : V1.PCLOCK) (UDP : V1_LWT.UDP) : sig
  val create : C.t -> UDP.t -> string -> UDP.ipaddr -> int -> Logs.reporter
end

open Result

module Tcp (C : V1.PCLOCK) (TCP : V1_LWT.TCP) : sig
  val create : C.t -> TCP.t -> string -> TCP.ipaddr -> int -> (Logs.reporter, string) result TCP.io
end
