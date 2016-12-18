open Lwt.Infix
open Result

module Udp (C : V1_LWT.CONSOLE) (CLOCK : V1.PCLOCK) (UDP : V1_LWT.UDPV4) = struct
  let create c clock udp ~hostname dst ?(port = 514) ?(truncate = 65535) () =
    let dsts =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.V4.to_string dst) port
    in
    Logs_syslog_lwt_common.syslog_report_common
      hostname
      truncate
      (* This API for PCLOCK is inconvenient (overengineered?) *)
      (fun () -> Ptime.v (CLOCK.now_d_ps clock))
      (fun s ->
         UDP.write ~dst ~dst_port:port udp (Cstruct.of_string s) >>= function
         | Ok _ -> Lwt.return_unit
         | Error e ->
           Format.(fprintf str_formatter "error %a %s, message: %s"
                     Mirage_pp.pp_udp_error e dsts s) ;
           C.log c (Format.flush_str_formatter ()))
end

module Tcp (C : V1_LWT.CONSOLE) (CLOCK : V1.PCLOCK) (TCP : V1_LWT.TCPV4) = struct
  open Logs_syslog

  let create c clock tcp ~hostname dst ?(port = 514) ?(truncate = 0) ?(framing = `Null) () =
    let f = ref None in
    let dsts =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.V4.to_string dst) port
    in
    let m = Lwt_mutex.create () in
    let connect () =
      TCP.create_connection tcp (dst, port) >|= function
      | Ok flow -> f := Some flow ; Ok ()
      | Error e ->
        Mirage_pp.pp_tcp_error Format.str_formatter e ;
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
        C.log c (Printf.sprintf "error %s, message %s" e msg)
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
          Mirage_pp.pp_flow_write_error Format.str_formatter e ;
          C.log c (Format.flush_str_formatter () ^ " " ^ dsts ^ ", reconnecting") >>= fun () ->
          reconnect send omsg
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            hostname
            truncate
            (fun () -> Ptime.v (CLOCK.now_d_ps clock))
            send)
    | Error e -> Error e
end
