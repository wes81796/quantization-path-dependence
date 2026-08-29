# Anchor mechanism test — quantization path dependence

This repository is the independent timestamp anchor for the quantization
path dependence pilot (protocol at C:\Development\quantization-path-dependence
on Wes's machine; see PROTOCOL.md §10/§15 there).

Mechanism: each preregistration freeze commits its bundle hash here and is
tagged; a GitHub Release on the tag records a server-side `created_at`
timestamp independent of any local clock.

This file is the mechanism test required by §15.1 ("independent
timestamp/remote-anchor mechanism named and tested"). Test performed
2026-08-29 by Claude under Wes's VIV authorization.

Reference protocol hash at test time (v0.3-draft):
SHA-256 B564593E0978559D672EF5CB2D2954521F562B279A26D93D51427B274F1341CB
