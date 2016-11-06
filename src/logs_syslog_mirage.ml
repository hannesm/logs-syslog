module Udp (C : V1_LWT.CONSOLE) (CLOCK : V1.CLOCK) (UDP : V1_LWT.UDPV4) = struct
  let create c udp ~hostname dest_ip ?(port = 514) () =
    let dst =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.V4.to_string dest_ip) port
    in
    Logs_syslog_lwt_common.syslog_report_common
      hostname
      (* This API for PCLOCK is inconvenient (overengineered?) *)
      (fun () -> match Ptime.of_float_s (CLOCK.time ()) with
         | None -> invalid_arg "couldn't read time"
         | Some t -> t)
      (fun s ->
         Lwt.catch (fun () ->
             UDP.write ~dest_ip ~dest_port:port udp (Cstruct.of_string s))
           (fun e -> C.log_s c (Printf.sprintf "error %s %s, message: %s"
                                  (Printexc.to_string e) dst s)))
end

module Tcp (C : V1_LWT.CONSOLE) (CLOCK : V1.CLOCK) (TCP : V1_LWT.TCPV4) = struct
  open Result
  open Lwt.Infix
  open Logs_syslog

  let err_to_string = function
    | `Unknown s -> s
    | `Timeout -> "timeout"
    | `Refused -> "refused"

  let create c tcp ~hostname dst ?(port = 514) ?(framing = `Null) () =
    let f = ref None in
    let dsts =
      Printf.sprintf "while writing to %s:%d" (Ipaddr.V4.to_string dst) port
    in
    let m = Lwt_mutex.create () in
    let connect () =
      Lwt.catch
        (fun () ->
           TCP.create_connection tcp (dst, port) >|= function
           | `Ok flow -> f := Some flow ; Ok ()
           | `Error e -> Error (err_to_string e))
        (fun e ->
           let s = Printf.sprintf "exception %s %s" (Printexc.to_string e) dsts
           in
           Lwt.return (Error s))
    in
    let reconnect k msg =
      Lwt_mutex.lock m >>= fun () ->
      (match !f with
       | None -> connect ()
       | Some _ -> Lwt.return (Ok ())) >>= function
      | Ok () -> Lwt_mutex.unlock m ; k msg
      | Error e ->
        Lwt_mutex.unlock m ;
        C.log_s c (Printf.sprintf "error %s, message %s" e msg)
    in
    let rec send omsg =
      match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.(of_string (frame_message omsg framing)) in
        Lwt.catch (fun () ->
            TCP.write flow msg >>= function
            | `Ok () -> Lwt.return_unit
            | `Eof ->
              f := None ;
              C.log_s c ("EOF " ^ dsts ^ ", reconnecting") >>= fun () ->
              reconnect send omsg
            | `Error e ->
              f := None ;
              let m =
                Printf.sprintf "error %s %s, reconnecting" (err_to_string e) dsts
              in
              C.log_s c m >>= fun () ->
              reconnect send omsg)
          (fun e ->
             f := None ;
             let msg =
               let exc = Printexc.to_string e in
               Printf.sprintf "exception %s %s, reconnecting" exc dsts
             in
             C.log_s c msg >>= fun () ->
             reconnect send omsg)
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            hostname
            (fun () -> match Ptime.of_float_s (CLOCK.time ()) with
               | None -> invalid_arg "couldn't read time"
               | Some t -> t)
            send)
    | Error e -> Error e
end
