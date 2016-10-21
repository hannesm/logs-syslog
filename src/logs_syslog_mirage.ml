
let syslog_report = Logs_syslog_lwt_common.syslog_report_common

module Udp (C : V1.PCLOCK) (UDP : V1_LWT.UDP) = struct
  let create clock udp host dst dst_port =
    syslog_report
      host
      (fun () -> Ptime.v (C.now_d_ps clock))
      (fun s -> UDP.write ~dst ~dst_port udp (Cstruct.of_string s))
end
