## 0.1.1 (2018-04-09)

- be honest about lwt.unix dependency in tls-syslog.lwt{.tls} (lwt 4.0 support)
- logs-syslog.lwt: no need to handle EAGAIN (already handled by Lwt_unix)

## 0.1.0 (2017-01-18)

- remove <4.03 compatibility
- Mirage: use STACK instead of UDP/TCP
- MirageOS3 support

## 0.0.2 (2016-11-06)

- Unix, TCP: wait (if something else reconnects) for 10 ms instead of 1s
- Lwt, UDP: remove unneeded mutex
- Lwt, TCP: lock in reconnect, close socket during at_exit
- Lwt, TLS: lock in reconnect, close socket during at_exit
- Mirage, TCP: respect ?framing argument
- Mirage: catch possible exceptions, print errors to console (now required)
- Mirage, TCP & TLS: lock in reconnect

## 0.0.1 (2016-10-31)

- initial release with Unix, Lwt, Mirage2 support