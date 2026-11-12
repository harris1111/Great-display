# Security Policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please do **not** open a public issue for security problems. Report them
privately through
[GitHub Security Advisories](https://github.com/thienduc12311/Great-display/security/advisories/new).

Include the affected version, macOS version, steps to reproduce and the impact
you see. You should get a reply within a week. Once a fix is released the
advisory is published with credit to the reporter, unless you prefer otherwise.

## Scope

Great Display runs as a regular user process. It uses the Accessibility
permission for the brightness/volume key event tap and Screen Recording for
display streaming. Issues where the app could be used to escalate privileges,
capture screen content without consent, or inject input are in scope.
