# Frozen Storage Layout

Status: fixed before the first source or tool payload retrieval on 2026-08-30.

## Roots and roles

- Control repository: `C:\Development\quantization-path-dependence`
  - version-controlled protocol, manifests, schemas, commands, validators, analysis code, and evidence summaries;
  - no model weights, GGUF payloads, or full-distribution shards.
- Heavy-object root: `F:\quantization-path-dependence`
  - source and tool payloads, build products, GGUF objects, full-distribution exports, diagnostic caches, logs, and temporary work;
  - maintain at least 160 GB free before source retrieval and recheck headroom at every phase gate.

## Fixed directory topology

```text
F:\quantization-path-dependence\
  source\
    model\<repository-id>\<full-revision>\files\
    toolchain\llama.cpp\17252c769a63c1cb650ce98ae309cf4de0da7778\repo\
  artifacts\
    objects\sha256\<first-two-hex>\<64-hex-digest>\payload.gguf
  exports\
    objects\sha256\<first-two-hex>\<64-hex-digest>\<lossless-shards-and-sidecars>
  logs\
    source\
    build\
    shakedown\
    runs\
  work\
    downloads\
    build\
    artifacts\
    exports\
```

`<repository-id>` replaces `/` with `--`. The Mistral source path is therefore:

```text
F:\quantization-path-dependence\source\model\mistralai--Mistral-7B-v0.3\caa1feb0e54d415e2df31207e5f4e273e33509b1\files\
```

## Immutability and promotion rules

1. Downloads enter `work\downloads` under an attempt ID. They are not scientific inputs until size, expected remote identity, and locally computed SHA-256 pass.
2. Verified source files are moved once into the pinned source-revision directory. A manifest in the control repository binds every relative path to byte size and SHA-256.
3. Builds occur only under `work\build`. The frozen toolchain manifest binds the Git tree/diff, environment, flags, build log, source hashes, and executable hashes. Scientific commands address verified executables by absolute path and hash.
4. GGUF payloads are first written under `work\artifacts`. After complete validation, each payload is moved into the SHA-256 object path derived from its complete file bytes. The directory name must equal the payload digest.
5. Export bundles are first completed and validated under `work\exports`, then placed under the SHA-256 digest of a canonical bundle manifest. Shards themselves retain individual SHA-256 values in that manifest.
6. Content-addressed payloads are never overwritten. A digest collision with unequal bytes is a hard stop. Partial or failed attempts stay in `work` with logs until disposition; they are never promoted by renaming over a validated object.
7. Canonical IDs such as `D4-a` exist only in versioned manifests that point to object hashes. No route name, command order, directory order, timestamp, or added metadata may leak a staged identity into a blinded bundle.
8. Content-addressed object directories are read-only after promotion. Deletion, replacement, link retargeting, or in-place metadata edits are prohibited during the study.
9. Logs are append-only by attempt ID. Every registered command retains stdout, stderr, exit status, start/end UTC timestamps, argv, environment fingerprint, input hashes, and output hashes.
10. The C: control repository is the authoritative map from study IDs to source/build/object evidence. The F: README is an operational mirror, not a substitute for committed manifests.

## Phase boundary

This layout permits source retrieval, pinned toolchain checkout/build, and non-study shakedown. It does not permit canonical target-model BF16 conversion, D4 creation, target-model calibration, treatment intermediates, or staged endpoints before their later frozen gates.

## Operational mirror at layout freeze

- `F:\quantization-path-dependence\README.md`
- Length: 1,182 bytes
- SHA-256: `1D3FA5F50691C37041D004477FD21353597864C37FBA0406EB7EFB787184CE3F`
- Free-space observation before retrieval: 650,348,380,160 bytes

The README digest is evidence that the heavy-object root displayed the same topology and phase boundary when this layout was committed.
