open Lwt.Infix

module Udp (CLOCK : Mirage_clock.PCLOCK) (STACK : Mirage_stack.V4) = struct
  module UDP = STACK.UDPV4

  let create stack ~hostname dst ?(port = 514) ?(truncate = 65535) ?facility () =
    Logs_syslog_lwt_common.syslog_report_common
      facility
      hostname
      truncate
      (fun () -> Ptime.v (CLOCK.now_d_ps ()))
      (fun s ->
         UDP.write ~dst ~dst_port:port (STACK.udpv4 stack) (Cstruct.of_string s) >|= function
         | Ok () -> ()
         | Error e -> Format.printf "syslog-udp error %a, message: %s\n%!" UDP.pp_error e s)
      Syslog_message.encode
end

module Tcp (CLOCK : Mirage_clock.PCLOCK) (STACK : Mirage_stack.V4) = struct
  open Logs_syslog
  module TCP = STACK.TCPV4

  let create stack ~hostname dst ?(port = 514) ?(truncate = 0) ?(framing = `Null) ?facility () =
    let tcp = STACK.tcpv4 stack in
    let f = ref None in
    let m = Lwt_mutex.create () in
    let connect () =
      TCP.create_connection tcp (dst, port) >|= function
      | Ok flow -> f := Some flow ; Ok ()
      | Error e -> Error (Fmt.to_to_string TCP.pp_error e)
    in
    let reconnect k msg =
      Lwt_mutex.lock m >>= fun () ->
      (match !f with
       | None -> connect ()
       | Some _ -> Lwt.return (Ok ())) >>= function
      | Ok () -> Lwt_mutex.unlock m ; k msg
      | Error e ->
        Lwt_mutex.unlock m;
        Printf.printf "syslog-tcp error %s, message %s\n%!" e msg;
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
          Format.printf "syslog-tcp error %a sending message %s\n%!"
            TCP.pp_write_error e omsg;
          reconnect send omsg
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            facility
            hostname
            truncate
            (fun () -> Ptime.v (CLOCK.now_d_ps ()))
            send
            Syslog_message.encode)
    | Error e -> Error e
end
