
let slevel = function
  | Logs.App -> Syslog_message.Informational
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
let message ?(facility = Syslog_message.System_Daemons) ~host ~source ~tags level timestamp message =
  Logs.Tag.pp_set ppf tags ;
  let tags = flush () in
  let message = Printf.sprintf "%s %s %s" source tags message in
  { Syslog_message.facility ; severity = slevel level ; timestamp ; hostname = host ; message }

type framing = [
  | `LineFeed
  | `Null
  | `Custom of string
  | `Count
]

let frame_message msg = function
  | `LineFeed -> msg ^ "\n"
  | `Null -> msg ^ "\000"
  | `Custom s -> msg ^ s
  | `Count -> Printf.sprintf "%d %s" (String.length msg) msg
