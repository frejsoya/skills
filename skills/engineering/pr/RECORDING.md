# Recording a terminal demo

A GIF of what a reviewer would otherwise run, embedded at the top of
**Evidence**. Needs `k7` and `agg` on PATH, and `ffmpeg` for the check.

1. **Pick the command.** The one command that proves the change, run as a
   reviewer would (`make setup`). Done when you can name it in one line. A demo
   that needs several commands is a typed session (step 3).

2. **Fresh machine.** For a setup or install change, record in a fresh
   checkout of the PR's head commit with an empty `HOME`, so first-run
   downloads show.

3. **Record.** One command:

   ```sh
   k7 rec --env=HOME="$(mktemp -d)" --columns=150 --rows=40 \
     -o demo.cast -- make setup
   ```

   Several commands: record `bash` instead of the command, type them at the
   prompt, then `exit`. This needs a person at a terminal, so ask the user to
   run it (`! k7 rec … -- bash`). The GIF shows the keys as they were typed:
   type steadily.

   A cram test (`.t`) would make this declarative, but `k7 play` writes only
   SVG or text from it, not the `.cast` that `agg` reads.

4. **Render.**

   ```sh
   agg --idle-time-limit 2 --fps-cap 10 --font-size 14 --last-frame-duration 4 \
     demo.cast demo.gif
   ```

   A GIF because Azure DevOps rejects SVG attachments and caps a PR body at
   4,000 characters, and GitHub shows a GIF inline too. 10 fps keeps progress
   bars from bloating the file.

5. **Check.** Extract a frame from the middle and the last one, and look at
   both:

   ```sh
   ffmpeg -v error -i demo.gif -vf "select=eq(n\,40)" -frames:v 1 mid.png
   ```

   Done when both read clearly and hold only what you would post publicly: no
   token, credential or internal hostname.

6. **Attach.** Azure DevOps: `POST` the GIF as the body of
   `{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{id}/attachments/demo.gif?api-version=7.1-preview.1`,
   then embed the `url` from the response as a Markdown image, with alt text
   saying what it shows, at the top of **Evidence**. GitHub has no upload API:
   give the user the GIF to drop into the PR body.

7. **Keep it current.** When a later push changes what the recording shows,
   re-record and attach it under a new name, then update the link.
