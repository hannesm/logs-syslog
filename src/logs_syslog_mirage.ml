module Udp (C : V1.CLOCK) (UDP : V1_LWT.UDP) = struct
  (* need a console for emergency messages (temporary network issues) *)

  let create udp ~hostname dest_ip ?(port = 514) () =
    let m = Lwt_mutex.create () in
    Logs_syslog_lwt_common.syslog_report_common
      hostname
      (* This API for PCLOCK is inconvenient (overengineered?) *)
      (fun () -> match Ptime.of_float_s (C.time ()) with
         | None -> invalid_arg "couldn't read time"
         | Some t -> t)
      (fun s ->
         (* in another world, we will need to handle potential errors, such as
            'no route to host' *)
         Lwt_mutex.with_lock m (fun () ->
             UDP.write ~dest_ip ~dest_port:port udp (Cstruct.of_string s)))
end

module Tcp (C : V1.CLOCK) (TCP : V1_LWT.TCP) = struct
  (* need a console for emergency messages (temporary network issues) *)
  open Result
  open Lwt.Infix
  open Logs_syslog

  let create tcp ~hostname dst ?(port = 514) ?(framing = `Null) () =
    let f = ref None in
    let m = Lwt_mutex.create () in
    let connect () =
      TCP.create_connection tcp (dst, port) >|= function
      | `Ok flow -> f := Some flow ; Ok ()
      | `Error e -> Error e
    in
    let reconnect k msg =
      connect () >>= function
      | Ok () -> Lwt_mutex.unlock m ; k msg
      | Error _ -> Lwt_mutex.unlock m ; Lwt.return_unit (* TODO: output error *)
    in
    let rec send omsg =
      Lwt_mutex.lock m >>= fun () ->
      match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.(of_string (frame_message omsg framing)) in
        TCP.write flow msg >>= function
        | `Ok () -> Lwt_mutex.unlock m ; Lwt.return_unit
        | `Eof | `Error _ -> f := None ; reconnect send omsg
            (* again, would be nice to report sth to the user *)
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            hostname
            (fun () -> match Ptime.of_float_s (C.time ()) with
               | None -> invalid_arg "couldn't read time"
               | Some t -> t)
            send)
    | Error _ -> Error "couldn't connect to log host"
end
