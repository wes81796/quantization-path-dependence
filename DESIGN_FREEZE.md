# Design Freeze v1.1

## Frozen design

- Study: **Quantization Path Dependence: Mistral 7B Pilot**
- Frozen protocol: `PROTOCOL.md`
- Protocol version: `0.4-draft`
- Protocol SHA-256: `7009A3A80C3389ABC491EC1B487C563EE491BBD9EB1981C59E611A482D96A933`
- Freeze date: 2026-08-30
- Anchor repository: `wes81796/quantization-path-dependence` (private)
- Authoritative anchor tag and Release: `design-freeze-v1.1`

The `-draft` suffix records the document's pre-freeze drafting lineage. This approved and anchored record is what changes its status: the exact bytes identified above are the approved, frozen v1 design.

Record v1.1 is a governance-wording correction only. Independent verification confirmed that `design-freeze-v1` was an annotated but cryptographically unsigned tag, so “signed” was replaced by “approved” and no protocol byte or design choice changed. The original commit, tag, and Release remain preserved as historical evidence.

## Authority and prerequisite disposition

All design-freeze prerequisites were satisfied before this record was created:

1. Claude independently reviewed the v0.4 file, verified its posted SHA-256, checked every agreed amendment in the text, reported no new objection, and gave unconditional design approval.
2. Wes stated on 2026-08-30: “run 13 s finished. The machine is released to your use. I approve the design freeze.”
3. Wes then supplied `VIV`, authorizing Codex to carry out the approved freeze and proceed under the protocol's gates.
4. The independently timestamped anchor mechanism had already been tested: private GitHub repository, annotated tag, and GitHub Release with API-provided server timestamps.
5. The artifact root is `F:\quantization-path-dependence`; the protocol's 160 GB reserve remains binding.
6. Wes is the nonce/mapping custodian. The sealed mapping must remain outside both agents' workspaces until the protocol's unblinding gate.

## Review disposition incorporated in v0.4

Claude's final review specifically confirmed:

- the exact nine-export matrix, including BF16×3 and D4-a×3 repeat baselines;
- the registered baseline scoping for denominator and Q4-only contrasts;
- the V1b→H1 and invalid-34→H3 not-evaluable branches;
- the hierarchical block sensitivity, immutable single-stratum behavioral clusters, and conditional inferential scope;
- complete executable independent analyzers and synthetic fixtures frozen before treatment creation, with only narrowly bounded and re-anchored mechanical repairs afterward;
- Claude's independent execution-input review checkpoint;
- the corrected usability wording and separation of the three pre-treatment preregistration locks from later mandatory evidence locks; and
- the named artifact root and updated nine-export planning envelope.

No review objection remained at freeze time.

## Evidence snapshot

The append-only coordination record after Codex's freeze claim, and before this Git commit, was:

- Path: `C:\Development\Coms\chat.md`
- SHA-256: `6C88FE3E1E267D98076D1331D1E7F9210D19E5C9C988AD402BF11A7BBCC7C639`
- Length: 66,806 bytes

This digest binds the recorded approvals and review disposition without placing the mutable coordination file itself inside the design repository.

## Freeze boundary

This commit contains the protocol and its governance disposition only. It does not contain or authorize an unrecorded change to an estimand, endpoint, threshold, selection frame, toolchain pin, or analysis rule. Subsequent source/tool preparation remains governed by v0.4 and must culminate in the separate execution-input freeze and Claude review specified there.

The design-freeze tag targets the exact commit containing this record. The corresponding GitHub Release provides the independent server-side timestamp; its API identifiers and timestamps are recorded in the coordination log after publication.
