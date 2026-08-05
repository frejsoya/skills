---
name: requests
description: "The requests HTTP client (Eio-based, modelled on Python's requests). Use when making HTTP GET/POST/PUT/DELETE calls from OCaml, handling Basic/Bearer/OAuth auth, uploading or downloading files, configuring retries and timeouts, or wiring an HTTP client into a cmdliner CLI."
---

# requests

HTTP/1.1 client for OCaml on Eio. Depend on `requests` for the pure core and
`requests-eio` for the IO layer.

**Everything goes through a session.** Cookies, connection pooling, shared auth,
retries, and the TLS and protocol policy all live on it, so reusing one session
is what gets you connection reuse.

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let session = Requests_eio.v ~sw ~clock:env#clock env#net in
  let resp = Requests_eio.get session "https://api.example.com/data" in
  print_endline (Requests_eio.Response.text resp)
```

Two entry points: `Requests_eio.v` takes a switch you already hold and a net of
your choosing; `Requests_eio.run` opens its own switch and hands back a session.

Connections opened by `run` close when its scope ends, so read the response
inside it:

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  let status =
    Requests_eio.run env @@ fun t ->
    Requests.Response.status_code (Requests_eio.get t "https://api.example.com")
  in
  Printf.printf "Status: %d\n" status
```

Requests on one session run concurrently and reuse connections:

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let session = Requests_eio.v ~sw ~clock:env#clock env#net in
  let session = Requests_eio.set_auth session (Requests.Auth.bearer ~token:"token") in
  (* Concurrent requests - connections reused *)
  let user, repos = Eio.Fiber.pair
    (fun () -> Requests_eio.get session "https://api.github.com/user")
    (fun () -> Requests_eio.get session "https://api.github.com/user/repos")
  in
  Printf.printf "user status: %d\nrepos status: %d\n"
    (Requests.Response.status_code user)
    (Requests.Response.status_code repos)
```

## Bodies and auth

`set_auth` returns a new session, so auth applies to every subsequent request
rather than being repeated per call.

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let session = Requests_eio.v ~sw ~clock:env#clock env#net in
  (* Bearer token *)
  let session = Requests_eio.set_auth session (Requests.Auth.bearer ~token:"token") in
  (* Basic auth *)
  let session =
    Requests_eio.set_auth session
      (Requests.Auth.basic ~username:"user" ~password:"pass")
  in
  Fmt.pr "configured: %a@." Requests_eio.pp session
```

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let session = Requests_eio.v ~sw ~clock:env#clock env#net in
  let body = Requests.Body.of_string Requests.Mime.json {|{"name": "Alice"}|} in
  let resp = Requests_eio.post session ~body "https://api.example.com/users" in
  Printf.printf "Status: %d\n" (Requests.Response.status_code resp)
```

File upload uses a real `multipart/form-data` body, never a hand-rolled one:

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let session = Requests_eio.v ~sw ~clock:env#clock env#net in
  let body =
    Requests.Body.multipart
      [
        {
          name = "file";
          filename = Some "doc.pdf";
          content_type = Requests.Mime.of_string "application/pdf";
          content = `String (Eio.Path.load Eio.Path.(env#fs / "doc.pdf"));
        };
      ]
  in
  let resp =
    Requests_eio.post session ~body "https://example.com/upload"
  in
  Printf.printf "Status: %d\n" (Requests.Response.status_code resp)
```

`download` streams to a sink instead of buffering the body:

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  Requests_eio.run env @@ fun t ->
  Eio.Path.with_open_out ~create:(`Or_truncate 0o644)
    Eio.Path.(env#fs / "file.zip")
  @@ fun sink ->
  ignore
    (Requests_eio.download t
       ~sink:(sink :> Eio.Flow.sink_ty Eio.Resource.t)
       "https://example.com/file.zip")
```

## Retries

Retry policy is session-wide, so it applies uniformly rather than being
reimplemented at each call site:

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let retry =
    Requests.Retry.config
      ~max_retries:3
      ~status_forcelist:[429; 500; 502; 503; 504]
      ()
  in
  let session = Requests_eio.v ~sw ~retry ~clock:env#clock env#net in
  Fmt.pr "session ready with retry: %a@." Requests_eio.pp session
```

## Responses

`Requests.Response` holds the status and headers; `Requests_eio.Response.text`
reads the body.

```ocaml
let run process handle_error =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let session = Requests_eio.v ~sw ~clock:env#clock env#net in
  let resp = Requests_eio.get session "https://api.example.com/data" in
  if Requests.Response.ok resp then
    let body = Requests_eio.Response.text resp in
    process body
  else
    let status = Requests.Response.status_code resp in
    handle_error status
```

## CLI integration

`Requests_cli.config_term` contributes the standard client flags (proxy, TLS,
timeouts) to your command, and `Requests_cli.v` turns the parsed config into a
session:

```ocaml
let run () =
  Eio_main.run @@ fun env ->
  let config_t = Requests_cli.config_term "myapp" env#fs in
  let run_with_session config =
    Eio.Switch.run @@ fun sw ->
    let session = Requests_cli.v config env sw in
    let resp = Requests_eio.get session "https://api.example.com/data" in
    Printf.printf "Status: %d\n" (Requests.Response.status_code resp)
  in
  let info = Cmdliner.Cmd.info "myapp" in
  let cmd =
    Cmdliner.Cmd.v info Cmdliner.Term.(const run_with_session $ config_t)
  in
  exit (Cmdliner.Cmd.eval cmd)
```
