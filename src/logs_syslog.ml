
(* XXX: are these good values? ask verbosemode! *)
let slevel = function
  | Logs.App -> Syslog_message.Critical
  | Logs.Error -> Syslog_message.Error
  | Logs.Warning -> Syslog_message.Warning
  | Logs.Info -> Syslog_message.Informational
  | Logs.Debug -> Syslog_message.Debug

let ppf, flush =
  let b = Buffer.create 255 in
  let ppf = Format.formatter_of_buffer b in
  let flush () =
    Format.pp_print_flush ppf () ;
    let s = Buffer.contents b in Buffer.clear b ; s
  in
  ppf, flush

(* TODO: can we derive the facility from the source? *)
let message ?(facility = Syslog_message.System_Daemons) ~host ~source level timestamp message =
  let message = source ^ ": " ^ message in
  { Syslog_message.facility ; severity = slevel level ; timestamp ; hostname = host ; message }
