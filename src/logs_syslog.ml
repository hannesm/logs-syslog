
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

let facility =
  let ppf ppf v =
    Syslog_message.string_of_facility v |> Format.pp_print_string ppf
  in
  Logs.Tag.def ~doc:"Syslog facility" "syslog-facility" ppf

let message ?facility:(syslog_facility = Syslog_message.System_Daemons)
    ~host:hostname ~source ~tags ?header level timestamp message =
  let tags =
    let tags = Logs.Tag.rem facility tags in
    if Logs.Tag.is_empty tags then
      ""
    else
      (Logs.Tag.pp_set ppf tags ;
       " " ^ flush ())
  in
  (* RFC 3164 4.1.3 notes that TAG (in this case, source) can be terminated by
     any non-alphanumeric character and explictly notes that space is valid.
     However, colon is more common and in at least one case the space is not
     sufficient for correct parsing of the message. All this is irrelevant in
     RFC 5424.
     (see https://github.com/hannesm/logs-syslog/issues/6) *)
  let source =
    let len = String.length source in
    if len > 0 && source.[len - 1] <> ':' then
      source ^ ":"
    else
      source
  in
  let hdr = match header with None -> "" | Some x -> " " ^ x in
  (* According to RFC 3164, source should be no more than 32 chars. *)
  let message = Printf.sprintf "%s%s%s %s" source tags hdr message
  and severity = slevel level
  in
  { Syslog_message.facility = syslog_facility ; severity ; timestamp ;
                   hostname ; message }

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
