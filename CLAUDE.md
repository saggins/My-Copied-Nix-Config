# CLAUDE.md

## Secrets
- Never write to `secrets/` (sops files) or run `sops` commands that modify them.
  The user manages secrets themselves.
- When a change needs a secret or key added, rotated, or removed, give the user the
  exact commands to run instead (key generation, `sops set ...`, cleanup), and leave
  any config that depends on the resulting public key for them to fill in.
