open Mirage

let libraries = ["duration"; "logs-syslog.mirage"; "logs.lwt"]
and packages = ["duration"; "logs-syslog"; "logs"]

let handler =
  foreign ~libraries ~packages "Unikernel.Main"
    (clock @-> time @-> stackv4 @-> job)

let stack = generic_stackv4 default_console tap0

let () =
  register "syslog" [handler $ default_clock $ default_time $ stack]
