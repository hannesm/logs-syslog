open Result

(* could use a FLOW instead, but then the reconnect logic would need to be elsewhere... *)
module Tls (C : V1.PCLOCK) (TCP : V1_LWT.TCP) (KV : V1_LWT.KV_RO) : sig
  val create : C.t -> TCP.t -> KV.t -> string -> TCP.ipaddr -> int -> (Logs.reporter, string) result TCP.io
end
