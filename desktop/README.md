# Triton Desktop

Shared QuickShell UI, themes, and assets live here. Keep each OS-specific QML
backend beside the QuickShell service that uses it. Keep OS command helpers and
native bridges under `platforms/{linux,freebsd}/`, and compositor IPC behind
the adapters under `compositors/` so the controls remain reusable.

`quickshell/` remains a GNU Stow package and deploys to `~/.config/quickshell`.
