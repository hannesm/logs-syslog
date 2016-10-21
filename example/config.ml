open Mirage

let libraries = ["duration"; "logs-syslog.mirage"; "logs.lwt"]
and packages = ["duration"; "logs-syslog"; "logs"]

let handler =
  foreign ~libraries ~packages "Unikernel.Main"
    (pclock @-> time @-> stackv4 @-> job)

let stack = generic_stackv4 tap0

let () =
  register "syslog" [handler $ default_posix_clock $ default_time $ stack]
