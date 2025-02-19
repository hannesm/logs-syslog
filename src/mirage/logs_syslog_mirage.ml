open Lwt.Infix

module Udp (STACK : Tcpip.Stack.V4V6) = struct
  module UDP = STACK.UDP

  let create stack ~hostname dst ?(port = 514) ?(truncate = 65535) ?facility () =
    let dsts =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.to_string dst) port
    in
    Logs_syslog_lwt_common.syslog_report_common
      facility
      hostname
      truncate
      Mirage_ptime.now
      (fun s ->
         UDP.write ~dst ~dst_port:port (STACK.udp stack) (Cstruct.of_string s) >>= function
         | Ok _ -> Lwt.return_unit
         | Error e ->
           Format.(fprintf str_formatter "error %a %s, message: %s"
                     UDP.pp_error e dsts s) ;
           Printf.printf "%s" (Format.flush_str_formatter ());
           Lwt.return_unit)
      Syslog_message.encode
end

module Tcp (STACK : Tcpip.Stack.V4V6) = struct
  open Logs_syslog
  module TCP = STACK.TCP

  let create stack ~hostname dst ?(port = 514) ?(truncate = 0) ?(framing = `Null) ?facility () =
    let tcp = STACK.tcp stack in
    let f = ref None in
    let dsts =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.to_string dst) port
    in
    let m = Lwt_mutex.create () in
    let connect () =
      TCP.create_connection tcp (dst, port) >|= function
      | Ok flow -> f := Some flow ; Ok ()
      | Error e ->
        TCP.pp_error Format.str_formatter e ;
        Error (Format.flush_str_formatter ())
    in
    let reconnect k msg =
      Lwt_mutex.lock m >>= fun () ->
      (match !f with
       | None -> connect ()
       | Some _ -> Lwt.return (Ok ())) >>= function
      | Ok () -> Lwt_mutex.unlock m ; k msg
      | Error e ->
        Lwt_mutex.unlock m ;
        Printf.printf "error %s, message %s" e msg ;
        Lwt.return_unit
    in
    let rec send omsg =
      match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.(of_string (frame_message omsg framing)) in
        TCP.write flow msg >>= function
        | Ok () -> Lwt.return_unit
        | Error e ->
          f := None ;
          TCP.pp_write_error Format.str_formatter e ;
          Printf.printf "%s %s, reconnecting"
            (Format.flush_str_formatter ()) dsts;
          reconnect send omsg
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            facility
            hostname
            truncate
            Mirage_ptime.now
            send
            Syslog_message.encode)
    | Error e -> Error e
end
