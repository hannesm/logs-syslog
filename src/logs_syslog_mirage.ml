module Udp (C : V1.PCLOCK) (UDP : V1_LWT.UDP) = struct
  (* need a console for emergency messages (temporary network issues) *)

  let create clock udp host dst dst_port =
    Logs_syslog_lwt_common.syslog_report_common
      host
      (* This API for PCLOCK is inconvenient (overengineered?) *)
      (fun () -> Ptime.v (C.now_d_ps clock))
      (fun s ->
         (* in another world, we will need to handle potential errors, such as
            'no route to host' *)
         UDP.write ~dst ~dst_port udp (Cstruct.of_string s))
end

module Tcp (C : V1.PCLOCK) (TCP : V1_LWT.TCP) = struct
  (* need a console for emergency messages (temporary network issues) *)
  open Result
  open Lwt.Infix

  let create clock tcp host dst dst_port =
    let f = ref None in
    let connect () =
      TCP.create_connection tcp (dst, dst_port) >|= function
      | `Ok flow -> f := Some flow ; Ok ()
      | `Error e -> Error e
    in
    let reconnect k msg =
      connect () >>= function
      | Ok () -> k msg
      | Error _ -> (* here, emit some error message! *) Lwt.return_unit
    in
    let rec send omsg = match !f with
      | None -> reconnect send omsg
      | Some flow ->
        let msg = Cstruct.(of_string (omsg ^ "\000")) in
        TCP.write flow msg >>= function
        | `Ok () -> Lwt.return_unit
        | `Eof | `Error _ -> f := None ; reconnect send omsg
            (* again, would be nice to report sth to the user *)
    in
    connect () >|= function
    | Ok () ->
      Ok (Logs_syslog_lwt_common.syslog_report_common
            host
            (fun () -> Ptime.v (C.now_d_ps clock))
            send)
    | Error _ -> Error "couldn't connect to log host"
end
