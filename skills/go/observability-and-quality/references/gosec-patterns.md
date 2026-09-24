# gosec findings on legitimate code — approved restructurings

Companion to the `observability-and-quality` skill, §9. These rules fire on shapes that
CLIs, test harnesses and API clients need. Apply the restructuring first; suppress only
where it is applied and the finding still fires, in the form
`//nolint:gosec // <rule>: <reason>` (or `//#nosec <rule> -- <reason>` when `gosec` runs
standalone rather than through `golangci-lint`).

| Finding | Legitimate case | Approved restructuring |
|---|---|---|
| G204 — subprocess launched with a variable | a test harness or CLI that spawns a binary | the binary's path comes from configuration or the environment, never from argv or user input; arguments go in a slice, never through a shell |
| G302 — file mode set with `chmod`, or a permissive mode on create | a CLI or test that must produce an owner-only file | never `chmod` an existing file: create it with the final mode (`0600`, exclusive create) in a private temporary directory and `rename` it into place; set the process umask where the ecosystem allows |
| G304 / G703 — file path from tainted input, path traversal | a CLI that opens the file the user named | open it through `os.Root` (Go 1.24+) rooted at the permitted directory, or `filepath.Clean` plus a prefix check against that directory; never join and hope |
| G704 — request to a variable URL (server-side request forgery) | an API client whose method name or resource id is part of the path | build the request from a **constant** base endpoint and a fixed path template, then attach body, query and headers after `NewRequest`; scheme and host never come from input, and any caller-supplied identifier is validated against an allowlist pattern before it enters the path |

Why the rules stay on: each one catches the real defect in product code — a shell built
from a string, a world-readable secret, a traversal, a request to an attacker-chosen host.
The table names the shapes that are *not* that defect; it does not license switching the
rule off.
