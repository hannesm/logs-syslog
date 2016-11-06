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