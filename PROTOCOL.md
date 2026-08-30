# Quantization Path Dependence: Mistral 7B Pilot Protocol

**Protocol version:** 0.4-draft  
**Draft date:** 2026-08-29  
**Status:** Draft for independent review; not yet frozen or preregistered  
**Authorization:** Wes issued `VIV` directly to Codex on 2026-08-29 and reaffirmed Codex's primary-coder role with `VIV` on 2026-08-30  
**Operational hold:** No build, download, conversion, inference, or other RAM/GPU-heavy work may begin until Wes explicitly confirms that valence-vividness run13 is finished and the machine is released.

## 1. Research question and causal scope

Is a final GGUF quantization label an incomplete model specification?

More precisely: starting from one canonical BF16 GGUF, do nominally matched ordinary-mixed `Q4_K_M` endpoints retain a measurable signature of a lossy intermediate route in tensor values, next-token distributions, and item-level behavior?

This is a provenance experiment, not a conventional Q4-versus-Q8 benchmark. The manipulated variable is the route before the matched endpoint. The causal contrast starts at the canonical BF16 GGUF; that artifact is a shared reference, not a native or ground-truth model. Claims are limited to the exact checkpoint revision, converter output, llama.cpp build, tensor recipe, routes, and evaluation configuration frozen here.

## 2. Prior evidence and novelty boundary

The study will not claim to discover requantization path dependence. llama.cpp PR #1691 introduced `--allow-requantize` and reported path-sensitive Q8_0→Q4_0 results on older LLaMA checkpoints: large in its 7B example and nearly absent in its limited 33B example.

This pilot instead tests a modern K-quant endpoint with:

- exact source, converter, build, and artifact provenance;
- independent direct-path and primary staged-path replicates;
- preregistered expected and observed per-tensor operation maps;
- tensor, distribution, behavior, and generation measurements;
- fixed paired inference and a document-cluster bootstrap;
- a frozen practical-magnitude rule; and
- independent blinded analysis.

A one-checkpoint pilot cannot establish a model-family, instruction-tuning, quantizer-wide, or universal quality claim.

## 3. Study object and planned pins

### 3.1 Source checkpoint

The planned source is the official base model `mistralai/Mistral-7B-v0.3` at full repository revision:

`caa1feb0e54d415e2df31207e5f4e273e33509b1`

The source config declares BF16. The source manifest must select one representation only: the three sharded safetensor files plus their index and the exact required config/tokenizer files. It must explicitly exclude the duplicate consolidated weight representation. Before retrieval, record the allowlist; after retrieval, record every filename, size, SHA-256, safetensors dtype histogram, tokenizer/config hash, license, and model-card URL.

Convert once with the pinned `convert_hf_to_gguf.py` using explicit `--outtype bf16`. Record the exact command, script hash, interpreter and dependency versions, and the resulting canonical BF16 GGUF's size, SHA-256, full metadata, and tensor manifest. Choosing F16 would create an extra preprocessing condition and is prohibited.

If the pinned revision or allowlisted representation cannot be retrieved exactly, pause for a protocol amendment; do not substitute another revision or file set.

### 3.2 Toolchain

The planned scientific toolchain is llama.cpp commit:

`17252c769a63c1cb650ce98ae309cf4de0da7778`

One pinned build must create and evaluate every endpoint. Before target-model calibration, freeze repository clean/dirty state and diff hash, submodule SHAs, compiler, CMake, CUDA toolkit and driver, build type and flags, binary hashes, and hashes for the relevant converter, quantizer, evaluator, and argument-parser sources. Record OS, CPU, RAM, GPU, driver, storage, and every quantization/evaluation flag, including explicit thread counts.

Ollama is excluded from primary creation and measurement. It may be used only under a later ecological-replication protocol.

## 4. Conditions and tensor operations

Let `BF16` denote the canonical GGUF reference. The planned artifacts are:

| Canonical ID | Lineage | Role |
|---|---|---|
| `D4-a` | BF16 → ordinary mixed Q4_K_M | Direct reference |
| `D4-b` | BF16 → ordinary mixed Q4_K_M, fresh process | Direct-path reproducibility control |
| `84-a` | BF16 → Q8_0 → ordinary mixed Q4_K_M | Primary staged endpoint |
| `84-b` | BF16 → fresh Q8_0 → ordinary mixed Q4_K_M | Primary-path reproducibility control |
| `64` | BF16 → Q6_K → ordinary mixed Q4_K_M | Descriptive partial-requantization path |
| `34` | BF16 → ordinary mixed Q3_K_M → ordinary mixed Q4_K_M | Heterogeneous positive-control bottleneck |

For a tensor whose stored type changes, a staged path means source payload → F32 decode buffer → selected final type. If the source and selected target types are equal, llama.cpp copies that tensor's payload rather than requantizing it. `general.file_type` is only a majority-type description; the preregistered unit is the per-tensor map.

Use exactly four operation labels:

- `quantized_from_BF16`;
- `requantized`;
- `copied_same_type`; and
- `copied_ineligible`.

Conditional on the pinned standard 32-layer untied Mistral inventory and no shape fallback, the expected eligible-tensor maps are:

| Artifact or final stage | Expected eligible map or operation count |
|---|---|
| direct Q4_K_M | 193 Q4_K + 33 Q6_K; 226 `quantized_from_BF16` |
| Q8_0 intermediate | 226 Q8_0 |
| Q6_K intermediate | 226 Q6_K |
| Q3_K_M intermediate | 129 Q3_K + 92 Q4_K + 4 Q5_K + 1 Q6_K |
| `84-*` final stage | 226 `requantized`, 0 eligible same-type copies |
| `64` final stage | 193 `requantized`, 33 `copied_same_type` |
| `34` final stage | 161 `requantized`, 65 `copied_same_type` |

These counts are assertions to test against the pinned build's logs and manifests, not facts to assume. Every artifact manifest records tensor name, shape, element count, role/layer where parseable, type, offset, byte length, payload hash, parent artifact SHA-256, expected operation, and observed operation. Stop before confirmatory evaluation if the actual inventory differs, an unexpected fallback occurs, the observed operation map differs, or an expected changed tensor retains its parent payload hash. Expected same-type copies in `64` and `34` are internal controls, not failures.

Fixed creation controls:

- no importance matrix;
- no `--leave-output-tensor`;
- no `--pure`;
- no `--tensor-type`, `--token-embedding-type`, `--output-tensor-type`, layer-pruning/copy-only option, or other tensor-type override;
- ordinary mixed recipes only;
- `--allow-requantize` present on the final `84-a`, `84-b`, `64`, and `34` commands and absent on BF16→direct and BF16→intermediate commands;
- identical pinned executable and explicit quantizer thread count for every repeat;
- identical final tensor names, shapes, and types across all Q4 endpoints.

A pure-format arm, reversed-route arm, or Q4→Q4 treatment requires a separate frozen protocol.

## 5. Registered hypotheses and validation claims

### V1a — direct-path reproducibility

`D4-a` and `D4-b` must have identical canonical tensor payloads. V1a is a pre-treatment gate and determines whether the tensor metric can be conditionally usable before staged artifacts exist.

### V1b — primary staged-path reproducibility

The two independently created Q8_0 intermediates must have identical canonical tensor payloads, and their `84-a` and `84-b` finals must also have identical canonical tensor payloads. V1b is a post-treatment validity gate required before H1 or promotion can pass.

For V1a and V1b, whole-file hashes should match; a whole-file mismatch is tolerable only when localized to preregistered non-semantic metadata while all tensor payloads and semantic metadata are identical.

### H1 — primary practical-lineage hypothesis

The `84-a` versus `D4-a` contrast will meet the frozen practical-lineage rule on at least two of the three primary metrics in Section 9: tensor distance, symmetrized full-distribution KL, and top-token disagreement.

### H2 — behavioral-displacement hypothesis

`84-a` will produce answer-margin displacement and choice churn beyond the repeated-`D4-a` evaluation baseline under the two separately reported support rules in Section 8.4. There is no registered prediction of signed accuracy loss.

### H3 — positive-control hypothesis

The valid `34` manipulation will meet the same two-of-three ancestry-detection rule. It is a heterogeneous mixed bottleneck, not a uniform low-bit model, and it neither triggers nor rescues primary promotion.

### S1 — descriptive Q6 path

`64` estimates a partial-requantization path. No monotonic ordering across `84`, `64`, and `34` is hypothesized.

Payload-code differences, observed-token probability shifts, perplexity, cosine similarity, sign flips, accuracy, and generation divergence are secondary or descriptive; none can replace a failed primary metric.

## 6. Data, serialization, and split freeze

All selections use frozen seed `20260829`. Three mutually exclusive groups are fixed by source revision, license, document/item ID, raw-byte hash, tokenizer hash, serialized-token hash, and selection trace before any staged artifact exists:

1. **Shakedown:** non-study material used only to test conversion, manifests, exporter correctness, parsers, and commands.
2. **Calibration:** four eligible documents contributing exactly 256 scored positions each (`N = 1,024`) plus 100 multiple-choice items. The four documents include at least one from each corpus stratum; the extra stratum is selected by the frozen seed. Calibration may measure runtime and pre-treatment reproducibility but may not tune the 10% rule or inspect any staged endpoint.
3. **Confirmatory:**
   - exactly 100 documents: 34 prose, 33 code, and 33 dialogue/instructional;
   - 75 documents contribute one 256-position scored block and 25 contribute two contiguous 256-position blocks, for exactly 32,000 scored positions;
   - long-window slots are allocated as 9 prose, 8 code, and 8 dialogue/instructional, selected independently of model output;
   - exactly 1,000 fixed multiple-choice items with ground-truth answers; and
   - exactly 128 fixed greedy-generation prompts.

Each corpus document is evaluated independently: a deterministic contiguous segment contains a 256-token unscored prefix followed by 256 or 512 scored target positions. Context never crosses document boundaries. The primary evaluator uses frozen `n_ctx = 1024`, and all endpoints receive identical serialized tokens, document ranges, block IDs, and scored-position masks. Persist raw byte ranges, tokenizer token ranges, selected offsets, input counts, scored counts, target token IDs, and hashes. A document must be long enough for its assigned segment before it enters the frozen sampling frame.

The dataset-manifest addendum must name every source, revision, license, selection frame, deterministic algorithm, exclusion applied before model evaluation, prompt byte serialization, BOS/EOS handling, and choice-scoring rule. Shared passages or sources define clusters for behavioral resampling. Calibration and confirmatory material cannot overlap. No importance-matrix, training, or threshold-selection data may be derived from either group.

## 7. Reproducibility and evaluator gates

### 7.1 Artifact creation

Create and validate `D4-a` and `D4-b` before calibration. They are two planned fresh processes, not retries. Canonical tensor-payload equality is mandatory. Create `84-a` and `84-b` only after the pre-treatment freeze; each starts with a separately created Q8_0 intermediate. The two intermediates must match each other, and the two final payloads must match each other. A mismatch fails V1b and prevents confirmatory treatment inference; it is not repaired by choosing the more convenient output.

Freeze a primary quantizer thread count at the execution-input freeze. If and only if the first `D4-a`/`D4-b` pair fails V1a because tensor payloads differ, one validation-triggered fallback is allowed: recreate both direct artifacts in fresh processes with quantizer threads = 1. Retain and label the failed pair and all logs. If the single-thread pair matches, it becomes the canonical direct pair and thread count one becomes mandatory for every later direct, intermediate, and final quantization command. If it does not match, hard stop. There is no post-treatment or V1b fallback. This is the sole validation-triggered artifact recreation and is distinct from the infrastructure retry in Section 11.3.

### 7.2 Matched inference configuration

Primary BF16-versus-Q4 and Q4-versus-Q4 measurements use one frozen configuration: model loader, backend, GPU-layer count and placement, KV types, flash-attention setting, context, batch, microbatch, evaluator threads, request order, and all other relevant flags. The feasible BF16 split constrains every primary endpoint. A fully offloaded Q4 run is a separately labeled ecological/efficiency check.

No Ollama process, concurrent model workload, speculative decoding, or parallel request is allowed during primary evaluation. Record actual placement and peak RAM/VRAM. If BF16 cannot run under the matched placement, the primary denominator is not silently replaced: either use a pre-treatment amended common configuration or label and quantify the placement difference and make the affected denominator ineligible for promotion.

### 7.3 Same-artifact evaluation gate

Before treatments, run `BF16` and `D4-a` three times each on the 1,024-position calibration corpus. Run `D4-a` three times on the 100-item calibration behavior set. On complete confirmatory material, run `BF16` and `D4-a` three times each on the 32,000-position corpus, and run `D4-a` three times on the behavioral and 128-prompt generation sets. BF16 receives no behavioral or generation run. Use identical bytes, order, binaries, settings, and environment.

- Full floating outputs may differ numerically; record maximum absolute logit difference and the registered distance baselines.
- Top-token IDs, multiple-choice selections, and greedy tokens must be exactly identical across repeats, using the frozen tie-break.
- One predeclared fallback is allowed before treatments: flash attention off, batch and microbatch one, evaluator thread count one, no parallelism, and otherwise the same matched placement. The complete study then uses that fallback configuration.
- If categorical outputs still differ, their tier is declared ineligible before treatment. No further fallback or ad hoc repeat is allowed.
- If fewer than two primary metrics are usable or conditionally usable after the fixed denominator/noise checks, no staged confirmatory study launches.

The first complete validator-passing output from a registered command is retained. An infrastructure failure may receive at most one identical-command retry; all attempts, logs, and output hashes remain in the manifest. A result mismatch is not an infrastructure failure and cannot trigger a retry.

### 7.4 Frozen endpoint-by-tier matrix

The execution-input freeze must contain this exact matrix and the exact command order:

| Endpoint | Artifact/tensor gate | Full confirmatory distribution export | Confirmatory behavior | Confirmatory generation |
|---|---:|---:|---:|---:|
| `BF16` | once | 3 | 0 | 0 |
| `D4-a` | once | 3 | 3 | 3 |
| `D4-b` | reproducibility only | 0 | 0 | 0 |
| `84-a` | once | 1 | 1 | 1 |
| `84-b` | reproducibility only | 0 | 0 | 0 |
| `64` | once | 1 | 1 | 1 |
| `34` | once | 1 | 1 | 1 |

All intermediates receive manifests and payload/type validation but no inference. Thus the primary corpus produces exactly nine full FP32 distribution exports. `D4-a` run 1 is the canonical comparator; its runs 2–3 and the BF16 runs estimate repeat noise. Native diagnostics follow their separate frozen stream and do not alter this matrix.

## 8. Measurement ladder

### 8.1 Gate A — artifact and tensor measurements

Let `Q` be the elements of tensors eligible for the common final ordinary-mixed Q4_K_M map. Dequantize every compared tensor through the same pinned implementation to FP32 and accumulate the following in FP64:

```text
d_W(A,B) = sqrt( sum[e in Q] (w_e^A - w_e^B)^2
                 / sum[e in Q] (w_e^BF16)^2 )
```

`d_W` is the tensor promotion metric. The denominator always uses the canonical BF16 reference values for the same elements. Copied-ineligible tensors are excluded from `Q` but reported separately.

Also report exact tensor payload identity, payload-code difference fractions where types match, per-tensor numerator contribution, cosine similarity, sign-flip rate, and summaries by layer, role, tensor size, and complete lineage tuple. These are secondary. Tensor localization does not identify causal layers without a later swap/ablation experiment.

### 8.2 Gate B — full next-token distributions

Native `llama-perplexity` does not export exact logits or independent token/document rows. Primary inference therefore requires a minimal pinned exporter that writes, for every eligible position:

- model/artifact SHA-256 and evaluator/config hash;
- document, block, and within-document position IDs;
- input and target token IDs; and
- the complete vocabulary-ordered FP32 logit vector.

The causal row contract is fixed: for target token at serialized index `t`, store the logits emitted at input position `t-1` under teacher forcing after the declared context reset and BOS handling. A vector emitted after consuming the target can never be paired with that target. An automated known-sequence test must fail on a one-token shift.

The exporter may use lossless sharding/compression only. Analysis recomputes FP64 log-softmax values and validates record counts, causal alignment, ordering, finite values, token hashes, and aggregate target loss. The source, build, executable, schema, parser, and validation tests are frozen before treatments. On a separately serialized native-compatible shakedown stream, configure the exporter to reproduce native chunk resets, BOS substitutions, and scoring mask; compare aggregate target loss and codec-aware directional KL against pinned llama.cpp behavior within a predeclared tolerance. The lossy cache is not expected to match exact-logit KL at floating-roundoff tolerance.

For eligible scored positions `u`, let `p_u^M` be the full next-token distribution from endpoint `M`. Define:

```text
SKL(p,q) = 1/2 * sum[v] { p_v log(p_v/q_v) + q_v log(q_v/p_v) }

d_KL(A,B)  = (1/N) * sum[u] SKL(p_u^A, p_u^B)

d_top(A,B) = (1/N) * sum[u] 1[argmax_v p_u^A != argmax_v p_u^B]
```

Compute log probabilities stably from FP32 logits in FP64. Exact ties choose the lowest vocabulary token ID. `d_KL` and `d_top` are the two distribution promotion metrics.

Secondary measures are target-token probability RMS,

```text
sqrt( (1/N) * sum[u] (p_u^A(y_u) - p_u^B(y_u))^2 ),
```

perplexity, mean target-probability change, directional KL components and percentiles, target-probability correlation, and maximum absolute logit difference. No aggregate-only output substitutes for the position-level records.

### 8.3 Native llama-perplexity diagnostic

As a secondary tool-validation diagnostic, create two native `.kld` bases: one from `BF16` for approximate `KL(BF16_cache || endpoint_live)` summaries and one from `D4-a` for approximate `KL(D4-a_cache || staged_live)` summaries. The base cache supplies `P` and the live candidate supplies `Q`; these diagnostics are directional `KL(P || Q)`, not symmetrized KL. The caches contain clipped/scaled uint16 reference log probabilities, not exact logits.

The native diagnostic uses a separately named and frozen native-compatible serialized stream and scoring mask. It is not the primary document-independent 32,000-position sample and is never pooled with or bootstrap-resampled as primary evidence. With `n_ctx = 1024` and non-strided evaluation, require at least `2*n_ctx` serialized input tokens and record `N_scored = n_chunks * 511`. Persist every chunk boundary, any chunk-start BOS substitution, and the exact native target indices.

Freeze the stream and chunking when each base is created; candidate flags cannot redefine its token sample. Require candidate context to equal the cache header and prohibit `--ppl-stride`. Because the cache itself stores only magic, `n_ctx`, vocabulary count, chunk count, token IDs, and coded probabilities, require a hashed sidecar binding cache SHA-256/size to producing model SHA-256, tokenizer GGUF-metadata hash, raw-stream and stored-token hashes, exact argv/binary/source hashes, requested and effective context/sequence settings, batch/microbatch/backend/offload/KV/flash-attention settings, BOS rule, chunk/scored mask and counts, and validator/parser version.

Validate the cache header, vocabulary count, exact token IDs, expected byte size, final summary sentinel, and absence of warnings or errors against that sidecar. Do not rely on process exit code alone. Run `D4-a` against its own base to measure the cache-codec/runtime floor. Native cumulative chunk lines are never treated as independent observations or bootstrapped.

### 8.4 Tier C — ground-truth behavior

For item `i` and option `j`, let the frozen continuation tokens be `T_ij` and define the length-normalized option score and correct-answer margin for every behavior-evaluated endpoint:

```text
s_ij(M) = (1 / |T_ij|) * sum[k in T_ij] log p_M(t_k | frozen prompt and prior option tokens)
m_i(M)  = s_i,correct(M) - max[j != correct] s_ij(M)
Delta_i(M) = m_i(M) - m_i(D4-a-run1),  M in {84-a, 64, 34}
```

Prompt bytes, tokenizer, prefix-space policy, BOS/EOS handling, continuation boundaries, and length normalization are frozen in the data manifest. Score ties choose the lowest canonical option index.

Define `D_margin(A,B) = mean_i |m_i(A)-m_i(B)|` and `D_choice(A,B)` as selected-answer disagreement rate. Let each behavioral baseline be the maximum corresponding distance over the three pairwise `D4-a` repeat comparisons, recomputed inside every bootstrap replicate. `D4-a` run 1 is the canonical reference; runs 2–3 serve only the baseline. Score `84-a`, `64`, and `34`; the registered H2 decision applies only to `84-a`, while `64` and `34` behavior is secondary.

The two H2 components are reported separately:

- margin displacement is supported only if the behavioral cluster-bootstrap one-sided 95% LCB of `D_margin(84-a,D4-a-run1) - B_margin` is greater than zero; and
- choice churn is supported only if repeated-`D4-a` choices are exactly equal and the behavioral cluster-bootstrap one-sided 95% LCB of `D_choice(84-a,D4-a-run1)` is greater than zero.

H2 is supported only if both registered components pass; the two components are still reported separately, and H2 does not affect or substitute for H1 promotion. Secondary summaries are signed mean displacement, correct→wrong, wrong→correct, wrong→different-wrong transitions, net accuracy difference, and accuracy. Use 10,000 paired cluster-bootstrap replicates stratified by benchmark/source, with shared-passage items retained together. Always report the exact McNemar test for correct/incorrect transitions; sparse discordance is described as low power, not used to omit it.

Equal aggregate accuracy is not behavioral equivalence when item churn exists. Behavior cannot trigger or rescue primary promotion.

### 8.5 Tier D — deterministic generation

On the 128 frozen prompts, use greedy decoding with a frozen maximum continuation length and report first divergent token, matched-prefix length, and any-divergence rate for `84-a`, `64`, and `34` versus `D4-a` run 1. Index continuation positions from one. Treat EOS as an ordinary token for divergence: if one endpoint emits EOS while the other emits a different token, that position is the first divergence; if both emit EOS at the same position after an identical prefix, record no divergence. If two continuations remain identical through the maximum length without a common EOS, record no observed divergence and right-censor matched-prefix length at that limit. Continuation after the first divergence is amplification, not independent evidence. Generated token sequences must be exact across same-artifact repeats. There is no LLM-judge score in this pilot.

## 9. Statistical plan and promotion rule

### 9.1 Fixed resampling

Distribution point estimates are token-weighted over all 32,000 eligible scored positions. Confidence intervals use exactly 10,000 paired, stratified document-cluster bootstrap replicates with RNG seed `20260829`: resample documents with replacement within corpus stratum, retain every scored position from each selected document, and use the identical sampled indices jointly across endpoints and contrasts. Recompute every distance, baseline, denominator, difference, and ratio within each replicate. Token-level confidence intervals are prohibited.

Report two-sided percentile 95% intervals. Promotion decisions use one-sided percentile 95% lower confidence bounds (LCBs) and upper confidence bounds (UCBs). A fixed sensitivity uses the named 256-position blocks: resample documents within stratum, then for each selected document draw exactly that document's original number of blocks with replacement from its own one or two blocks, retaining all positions in each selected block. For every promotion inequality, use the less favorable result: the smaller of document and block LCBs or the larger of their UCBs.

The same 10,000-replicate paired rule applies to behavioral items. Every item receives one immutable cluster ID before model evaluation; all items sharing a passage/source remain together, every cluster belongs to exactly one frozen benchmark/source stratum, and a cluster may not span strata. Corpus document-macro summaries are secondary to the registered token-weighted point estimates.

These intervals quantify sampling/robustness within the frozen corpus and explicitly named selection frames. They do not quantify uncertainty over checkpoints, model families, quantizers, builds, toolchains, or natural language generally. Generalization beyond a named probability-sampled frame requires a fresh replication.

### 9.2 Full-step, lineage, and baseline distances

For each primary metric `m`, on identical frozen elements or positions define:

- `F_m = d_m(D4-a-run1, BF16-run1)`, the ordinary direct-quantization distance;
- `L_m = d_m(84-a, D4-a-run1)`, the primary lineage distance;
- `R_m = L_m / F_m` when the denominator is usable.

For `d_W`, the run suffixes are irrelevant: define `B_W = d_W(D4-a,D4-b)`; V1a requires exact payload equality, hence `B_W = 0`.

For each sampled distribution metric, `D4-a` run 1 and BF16 run 1 are the canonical references. Define, and recompute within every bootstrap replicate:

- `B_m^D4`: the maximum of the three pairwise distances among the three `D4-a` confirmatory exports;
- `B_m^BF16`: the maximum of the three pairwise distances among the three BF16 confirmatory exports; and
- `B_m^F = max(B_m^D4, B_m^BF16)`, the conservative denominator-noise baseline.

`B_m^F` governs usability of the full-step denominator `F_m`. `B_m^D4` alone governs the staged-versus-direct lineage contrast `L_m`, because BF16 does not enter that contrast.

The fixed numerical floors are:

- `epsilon_W = 1e-12`;
- `epsilon_KL = 1e-12`; and
- `epsilon_top = 1 / 32000`.

For `d_W`, the denominator is conditionally usable before treatment only if V1a passes and `F_W > epsilon_W`; the `84` tensor metric cannot pass later unless V1b also passes. For a sampled distribution metric, let `U_B^F` be the less-favorable one-sided 95% UCB for `B_m^F`. Its denominator is usable only if its less-favorable one-sided 95% LCB for `F_m` exceeds `max(epsilon_m, 5*U_B^F)` and at least 99% of bootstrap draws in both resampling analyses satisfy `F_m(r) > max(epsilon_m, 5*B_m^F(r))`. Exact full-corpus BF16 and D4 categorical repeatability is additionally required for `d_top`.

### 9.3 Frozen metric-pass and study-promotion rules

The practical lineage fraction is fixed now at 10%; calibration cannot change it.

`d_W` passes when all of the following hold:

1. its denominator is usable;
2. `L_W > max(epsilon_W, B_W)`; and
3. `L_W / F_W >= 0.10`.

A sampled distribution metric passes when all of the following hold under both document and block analyses. Let `U_B^D4` be the less-favorable one-sided 95% UCB for `B_m^D4`:

1. its denominator is usable;
2. the point estimate `L_m >= max(epsilon_m, 5*U_B^D4)`;
3. the one-sided 95% LCB of `L_m - B_m^D4` is greater than zero; and
4. the one-sided 95% LCB of `L_m / F_m` is at least `0.10`.

No bootstrap replicate is dropped, clipped, or repaired. If any required `F_m,r` is zero or nonfinite, the ratio interval is undefined and that sampled metric is ineligible.

H1's `84` metric rule passes only if V1a and V1b pass and at least two of the three primary metrics (`d_W`, `d_KL`, `d_top`) are usable and pass. If fewer than two are usable or conditionally usable at the pre-treatment denominator/noise gate, the staged confirmatory study does not launch and the outcome is sensitivity-inconclusive. If V1b or another primary-path validity gate fails, H1 is not evaluable rather than false. If the path is valid and at least two launch-eligible metrics exist but fewer than two pass after treatment, H1 fails. Broader study promotion additionally requires the positive-control disposition in Section 9.4.

This two-of-three practical rule is a preregistered heuristic, not a family-wise-error-controlled omnibus test. Report every metric and interval; no secondary metric, `64`, behavior result, or generation result can substitute for a failed primary metric.

### 9.4 Positive-control interpretation

`34` manipulation validity requires V1a, its frozen operation map, all expected changed tensors to change payload, and all expected same-type tensors to retain payload. It does not depend on V1b. Its assay-detection rule is the same two-of-three rule against `D4-a`, but it never triggers promotion.

- `84` fails and `34` passes: the assay detects a strong heterogeneous bottleneck but not the registered Q8 ancestry magnitude.
- Both fail: the pilot is sensitivity-inconclusive for path ancestry at the registered scale.
- The `84` metric rule passes and `34` fails: retain the checkpoint signal, flag the control anomaly, and do not promote without a fresh replication.
- Both pass: the study promotes under H1; report `34` only as the positive control.
- If `34` is invalid, incomplete, or ineligible, H3 is not evaluable. Report any valid H1 signal, but broader promotion is unavailable.

No monotonic inference is made from `64`, and neither `34` nor `64` rescues `84`.

## 10. Blinding, commitments, and independent implementation

After direct-only calibration and before treatment creation:

1. Preassign random opaque condition codes for `84-a`, `64`, and `34`. The BF16 and canonical `D4-a` reference roles are explicitly visible; only the three staged-route identities remain blinded.
2. Generate a random 256-bit nonce and canonical sorted mapping JSON. Publish only `SHA256(nonce || canonical_mapping_json)` and retain the nonce/mapping outside both analysis workspaces.
3. Store every artifact internally by content SHA-256. After creation, bind opaque codes to artifact hashes in a sealed addendum and publish a second salted commitment before evaluation.
4. Exclude `D4-b` and `84-b` from the blind evaluation bundle after their required payload equality is verified; they are reproducibility controls, not extra samples.
5. Expose the visible references plus staged opaque codes, content hashes, immutable validated artifacts, the frozen analysis specification, and metric schema. Do not reveal staged lineage through filenames, added metadata, command logs, directory order, or table order.
6. Codex and Claude independently implement the tensor and distribution analysis. Each emits the complete pairwise matrix across the visible references and staged opaque IDs, not only selected contrasts.
7. Before treatment, freeze an **analysis-specification bundle** containing each analyst's complete executable implementation and environment lock, independent source commit, shared schemas/interfaces, synthetic fixtures, the mandatory causal one-token-shift failure fixture, canonical-run rule, commands, tolerances, and reconciliation rules. Both implementations must run successfully on the frozen synthetic fixtures before treatment creation.
8. After opaque evaluation and before analysis, freeze a **blinded input bundle** containing artifact/input hashes and raw evaluator outputs.
9. After blinded inputs exist, an analyst may make only an auditable mechanical repair for parsing, I/O, or environment compatibility that leaves every estimand, threshold, comparison, and rule unchanged. Record the diff and reason, rerun the synthetic fixtures, and independently re-anchor the implementation before computing or replacing results.
10. Any estimand-, threshold-, endpoint-, sample-, or decision-rule change reclassifies this checkpoint as exploratory. It cannot be described as a mechanical reconciliation.
11. Each analyst freezes a separate **result bundle** containing exact source/environment hashes, command log, input hashes, parsed tables, diagnostics, allowed repair log, and result hash.
12. Neither analyst reads the other's implementation or numerical summaries until both result bundles are frozen and independently anchored.
13. Reconcile discrepancies under the frozen rules while staged routes remain blinded. Unresolved implementation disagreement prevents unblinding and promotion. Wes must authorize any design amendment, which makes the affected checkpoint exploratory.
14. V1a is independently verifiable before treatment because `D4-a` is visible. V1b is an operator hard gate before effect analysis; its replicate artifacts and equality manifests are independently rechecked only after both blinded result bundles freeze, so their content hashes cannot reveal `84-a` early.
15. Reveal the nonce and both canonical mappings only after reconciliation, verify the commitments, derive the registered contrasts, and complete the independent V1b check.

`C:\Development\Coms\chat.md` is append-only by working convention but not tamper-evident. Hash announcements there are coordination records only. Every preregistration, blinded-input, implementation-repair, and result freeze requires an immutable Git commit plus an independently timestamped remote anchor (a private remote signed/tagged commit or a named RFC 3161/OpenTimestamps receipt) selected before design approval. If no such anchor is available, the study may proceed only as an explicitly non-preregistered exploratory run.

This is procedural blinding, not an operating-system security boundary. The pipeline operator may know lineage; analysis code must remain path-agnostic and interpretation waits for verified unblinding.

With only three staged candidates and a plausible magnitude ordering, an analyst may infer route identities from the results. The blinding is intended to prevent label-directed code paths, contrast selection, and premature interpretation; it does not guarantee analyst ignorance. The report must disclose any inferred identity or accidental clue before formal unblinding.

## 11. Stopping, missingness, retries, and deviations

### 11.1 Pre-treatment hard stops

Do not create a staged artifact if:

- the operational machine-release hold remains active;
- source, converter, build, binary, tokenizer, or data identity is missing or mismatched;
- canonical BF16 validation/provenance or `D4-a`/`D4-b` payload reproducibility fails;
- the exporter/native cross-check or record validator fails;
- fewer than two primary metric denominators are usable or conditionally usable under Section 9;
- the matched evaluator configuration cannot be frozen;
- the frozen analysis-specification bundle, opaque mapping commitment, or independent anchor is absent; or
- measured RAM, VRAM, storage, or runtime headroom is insufficient for the frozen plan.

### 11.2 Post-treatment artifact failures

An endpoint is invalid if tensor names/shapes/final types differ, an unexpected shape fallback occurs, the observed operation map differs from the frozen expected map, an expected changed tensor retains its parent payload, or required provenance is incomplete. Expected `copied_same_type` and `copied_ineligible` operations are valid.

`84-a`/`84-b` payload mismatch invalidates the primary path and makes H1 not evaluable, not false. A failed endpoint is not replaced by selecting a different attempt or nearby quantization. Complete all other frozen valid endpoints and mark every affected contrast incomplete.

### 11.3 Retries and missing observations

Each command may receive at most one identical retry for a documented infrastructure interruption such as power, I/O, or process failure. The first complete validator-passing output wins; every attempt and log is retained. Except for the explicitly preregistered V1a single-thread fallback in Section 7.1, validation failure, unexpected metric value, or unfavorable result is not a retry reason.

An outcome-independent source/schema defect discovered before any target-model evaluation may be removed symmetrically and replaced through the frozen selection algorithm, with the manifest version advanced and re-anchored. Once any BF16 or D4 target-model output has been inspected, replacement requires discarding those outputs and restarting from a newly frozen manifest; otherwise the record remains missing. After treatment begins, condition-specific deletion, imputation, replacement, or changed tokenization is prohibited. Any unresolved missing token, item, document, or endpoint makes its paired contrast incomplete; report exact planned and observed counts.

### 11.4 Effect-independent completion

Once valid treatment evaluation begins, do not stop, enlarge, shrink, substitute, or change metrics based on observed effects. Complete all valid frozen endpoints within the resource cap. If `84` fails, report bounds and do not add an order contrast, `--pure` arm, larger suite, or instruct checkpoint as a rescue. If `84` passes, any extension still requires a separate protocol.

A prematurely created staged artifact, unlogged substitution, post-treatment rule change, or material blind leak reclassifies this checkpoint as exploratory. A fresh checkpoint and fresh freeze are required for confirmatory replication. All deviations and exclusions appear before interpretation.

## 12. Three pre-treatment preregistration locks, later evidence locks, and ownership

The three pre-treatment preregistration locks are the design freeze, execution-input freeze, and pre-treatment freeze. The later blinded-input, implementation-repair, and result-bundle locks are equally mandatory evidence-integrity controls; “three” does not make them optional.

1. **Draft and review:** Codex authors; Claude reviews independently through the shared communication file. Resolve every material comment.
2. **Design freeze:** Wes approves protocol version, hypotheses, metric formulas, 10% rule, resampling, data counts, retry/missingness rules, and freeze mechanism. Commit and independently anchor the protocol plus review disposition. This locks the design but is not the complete preregistration.
3. **Machine release:** Wes explicitly states that valence-vividness run13 is finished and the machine is released.
4. **Source/tool preparation:** retrieve only the allowlisted source, build the pinned toolchain/exporter, and capture full provenance.
5. **Shakedown:** validate commands, tensor manifests, exporter records, native diagnostic cross-check, and resource usage on non-study material.
6. **Execution-input freeze:** before any D4 creation or target-model calibration, Claude independently reviews and dispositions the exact nine-run matrix, source allowlist/commands, toolchain/build/binary provenance, exporter/shard schema and causal fixtures, parser/tests, numeric-tolerance derivation, shakedown disposition, full calibration/confirmatory data manifest, tensor payload/metadata semantics, native-diagnostic stream, and evaluation schemas. After all material comments are resolved, commit and independently anchor the bundle. Later freezes incorporate this lock unchanged unless a declared restart is approved.
7. **Direct controls:** create and validate canonical `BF16`, then `D4-a` and `D4-b`. The direct repeat must precede calibration.
8. **Direct-only calibration and baseline:** use only `BF16` and `D4-a`; execute the fixed repeat gates and full confirmatory denominator/baseline runs. Apply the already-frozen usability formulas; do not choose new thresholds.
9. **Pre-treatment freeze:** freeze the direct artifact manifests, matched runtime configuration, metric eligibility, resource cap, both complete executable analysis implementations and synthetic fixtures, opaque-code commitment, and exact commands while incorporating the execution-input lock unchanged. Commit and independently anchor them. This completes preregistration.
10. **Treatment creation:** independently create `84-a` and `84-b`, then `64` and `34`; retain intermediates and validate every operation map and reproducibility gate.
11. **Opaque evaluation and input freeze:** evaluate each unique valid endpoint once under the frozen schedule; repeats exist only where preregistered. Freeze and independently anchor the blinded input bundle before either analyst computes treatment summaries.
12. **Independent analysis:** Codex and Claude freeze and independently anchor separate complete result bundles, exchange, and reconcile while staged routes remain blinded. Any permitted mechanical code repair follows Section 10 and receives its own evidence lock; unresolved disagreement prevents the next step.
13. **Unblind and report:** reveal and verify nonce/mappings, derive canonical contrasts, apply the frozen rule, and report all valid endpoints and failures.

No edit to `C:\Development\valence-vividness`, and no inspection or interference with its active process, belongs to this pilot. A future subtle-phenotype or runner-identity extension requires a separate claim and review.

## 13. Resource envelope

Verified planning hardware:

- NVIDIA RTX 2080 Ti, 11 GB VRAM;
- AMD Ryzen 9 3950X, 16 cores / 32 threads;
- 32 GB system RAM;
- approximately 606 GB free on `F:` at planning time.

Planned pilot envelope:

- artifact root: `F:\quantization-path-dependence`, with final content-addressed layout frozen before retrieval;
- reserve at least 160 GB before source retrieval; retain the selected source representation, BF16 reference, all intermediates/endpoints/replicates, lossless FP32 logit shards, two native diagnostic caches, logs, conversion transients, and manifests;
- nine full confirmatory FP32 exports occupy approximately 38 GB decimal before filesystem/compression variation;
- a rough pre-calibration expectation of 6–18 active GPU-hours and 16–48 wall-clock hours, explicitly treated as a ±2× planning range until the nine-export schedule is benchmarked;
- conversion and quantization are primarily CPU/disk work;
- BF16 matched-placement evaluation is the main RAM and wall-time constraint;
- direct-only shakedown/calibration freezes a hard total runtime cap before treatment; if the full fixed design does not fit, do not launch it.

No estimate or cap overrides the operational hold, provenance gates, or validity rules.

## 14. Reporting commitments

The report will distinguish payload difference, unsigned distributional drift, answer churn, and signed quality change. It will distinguish the shared source→BF16 conversion from the controlled route contrast, one-checkpoint evidence from generalization, exact payload reproducibility from numerical evaluator reproducibility, and planned primary results from secondary/exploratory findings.

Report every valid path, complete provenance, operation maps, point estimates and intervals, pre-treatment metric eligibility, failures, missing counts, deviations, blind reconciliation, and both independent implementations. Null downstream findings are bounded sensitivity statements, not proof of no path dependence. Avoid “identical models,” “quantization always degrades,” “all Q4_K_M models,” “native ground truth,” and “reproducible ancestry” unless the corresponding exact replicate gate passed.

## 15. Required freeze items

### 15.1 Before the design freeze

- [ ] Claude review and disposition of every material comment.
- [ ] Wes approval of the final protocol design.
- [ ] Hypotheses, formulas, 10% rule, bootstrap seed/replicates, data counts, tie-breaks, retries, missingness, and positive-control interpretation fixed.
- [ ] Independent timestamp/remote-anchor mechanism named and tested.
- [ ] Protocol and review-disposition hashes committed, independently anchored, and recorded in the coordination chat.

### 15.2 Before the execution-input freeze

- [ ] Explicit confirmation that run13 is finished and the machine is released.
- [ ] Exact source allowlist, full revision, file hashes/sizes, dtype histogram, tokenizer/config hashes, and license.
- [ ] Exact canonical BF16 conversion command plus converter-script, interpreter, and dependency hashes/versions.
- [ ] Exact llama.cpp revision, repository state, submodules, build environment/flags, source hashes, and executable hashes.
- [ ] Pinned exporter, schema, parser, validation tests, and native diagnostic cross-check.
- [ ] Named numeric exporter/native cross-check tolerances, documented derivation, and non-study shakedown results.
- [ ] Exact nine-export endpoint-by-tier matrix and command order.
- [ ] Dataset sources/revisions/licenses, selection trace, item/document IDs, raw and token hashes, byte/token ranges, block IDs, scored masks, and exact counts.
- [ ] Prompt serialization, BOS/EOS and prefix-space rules, option continuations, choice scoring, tie-break, and generation limit.
- [ ] Frozen tensor payload/padding, semantic/nonsemantic metadata, dequantizer, and native-diagnostic-stream definitions.
- [ ] Claude's independent execution-input review and disposition of every material comment.
- [ ] Execution-input commit and independent timestamp/remote anchor recorded before target-model conversion or calibration.

### 15.3 Before the pre-treatment freeze

- [ ] Canonical BF16 GGUF artifact hash/size/metadata and per-tensor manifest.
- [ ] `D4-a`/`D4-b` exact payload equality and complete creation logs.
- [ ] Matched backend/offload/KV/attention/context/batch/microbatch/thread configuration and measured resource cap.
- [ ] Three full BF16 and three full `D4-a` distribution exports, direct-only numerical baselines, denominator-usability results, and frozen metric-eligibility table.
- [ ] Opaque-code generation, 256-bit nonce custody, commitment, and content-address/binding procedure.
- [ ] Both complete executable analysis implementations, environment locks, synthetic fixtures, and successful fixture results frozen without either analyst seeing treatment data.
- [ ] Full preregistration-bundle commit and independent timestamp/remote anchor recorded before any Q8_0, Q6_K, or Q3_K_M treatment intermediate exists.

The design freeze prevents untracked changes to the study plan. The study is not fully preregistered until every pre-treatment item is frozen and no staged endpoint has been created.

## 16. Primary sources

- pinned llama.cpp quantizer documentation: https://github.com/ggml-org/llama.cpp/blob/17252c769a63c1cb650ce98ae309cf4de0da7778/tools/quantize/README.md
- pinned llama.cpp quantizer implementation: https://github.com/ggml-org/llama.cpp/blob/17252c769a63c1cb650ce98ae309cf4de0da7778/src/llama-quant.cpp
- pinned llama.cpp perplexity/KL documentation: https://github.com/ggml-org/llama.cpp/blob/17252c769a63c1cb650ce98ae309cf4de0da7778/tools/perplexity/README.md
- pinned llama.cpp perplexity/cache implementation: https://github.com/ggml-org/llama.cpp/blob/17252c769a63c1cb650ce98ae309cf4de0da7778/tools/perplexity/perplexity.cpp
- pinned GGUF specification: https://github.com/ggml-org/llama.cpp/blob/17252c769a63c1cb650ce98ae309cf4de0da7778/ggml/docs/gguf.md
- llama.cpp requantization prior art, PR #1691: https://github.com/ggml-org/llama.cpp/pull/1691
- pinned Mistral 7B v0.3 official repository: https://huggingface.co/mistralai/Mistral-7B-v0.3/tree/caa1feb0e54d415e2df31207e5f4e273e33509b1
- pinned Mistral configuration: https://huggingface.co/mistralai/Mistral-7B-v0.3/blob/caa1feb0e54d415e2df31207e5f4e273e33509b1/config.json
- Ollama GGUF import documentation, secondary runtime only: https://docs.ollama.com/import
