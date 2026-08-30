#!/usr/bin/env python3
"""Validate the frozen Mistral sharded-safetensors set without loading tensors."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import stat
import struct
import sys
from collections import Counter
from pathlib import Path
from typing import Any


EXPECTED_SHARDS = (
    "model-00001-of-00003.safetensors",
    "model-00002-of-00003.safetensors",
    "model-00003-of-00003.safetensors",
)

DTYPE_BYTES = {
    "BOOL": 1,
    "U8": 1,
    "I8": 1,
    "F8_E4M3": 1,
    "F8_E5M2": 1,
    "U16": 2,
    "I16": 2,
    "F16": 2,
    "BF16": 2,
    "U32": 4,
    "I32": 4,
    "F32": 4,
    "U64": 8,
    "I64": 8,
    "F64": 8,
}


class ValidationError(RuntimeError):
    pass


def is_reparse_point(path: Path) -> bool:
    info = path.lstat()
    attrs = getattr(info, "st_file_attributes", 0)
    marker = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    return bool(attrs & marker)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def read_exact(stream, count: int) -> bytes:
    chunks: list[bytes] = []
    remaining = count
    while remaining:
        chunk = stream.read(remaining)
        if not chunk:
            raise ValidationError(f"Unexpected EOF with {remaining} bytes left to read")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def validate_shard(path: Path) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    if not path.is_file() or path.is_symlink() or is_reparse_point(path):
        raise ValidationError(f"Shard is not a plain file: {path}")

    file_bytes = path.stat().st_size
    with path.open("rb") as stream:
        header_length = struct.unpack("<Q", read_exact(stream, 8))[0]
        if header_length < 2 or header_length > 100_000_000:
            raise ValidationError(f"Implausible safetensors header length in {path.name}: {header_length}")
        if 8 + header_length > file_bytes:
            raise ValidationError(f"Safetensors header exceeds file length in {path.name}")
        header_bytes = read_exact(stream, header_length)

    try:
        header = json.loads(header_bytes.decode("utf-8", errors="strict"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f"Invalid UTF-8/JSON safetensors header in {path.name}: {exc}") from exc
    if not isinstance(header, dict):
        raise ValidationError(f"Safetensors header is not an object in {path.name}")

    payload_bytes = file_bytes - 8 - header_length
    tensors: dict[str, dict[str, Any]] = {}
    intervals: list[tuple[int, int, str]] = []
    dtype_histogram: Counter[str] = Counter()
    tensor_bytes_by_dtype: Counter[str] = Counter()

    for name, entry in header.items():
        if name == "__metadata__":
            if not isinstance(entry, dict):
                raise ValidationError(f"__metadata__ is not an object in {path.name}")
            continue
        if not isinstance(name, str) or not isinstance(entry, dict):
            raise ValidationError(f"Malformed tensor entry in {path.name}")

        dtype = entry.get("dtype")
        shape = entry.get("shape")
        offsets = entry.get("data_offsets")
        if dtype not in DTYPE_BYTES:
            raise ValidationError(f"Unsupported dtype {dtype!r} for {name} in {path.name}")
        if not isinstance(shape, list) or any(not isinstance(x, int) or x < 0 for x in shape):
            raise ValidationError(f"Invalid shape for {name} in {path.name}")
        if (
            not isinstance(offsets, list)
            or len(offsets) != 2
            or any(not isinstance(x, int) for x in offsets)
        ):
            raise ValidationError(f"Invalid data_offsets for {name} in {path.name}")

        start, end = offsets
        if start < 0 or end < start or end > payload_bytes:
            raise ValidationError(f"Out-of-range data_offsets for {name} in {path.name}")
        expected_tensor_bytes = math.prod(shape) * DTYPE_BYTES[dtype]
        if end - start != expected_tensor_bytes:
            raise ValidationError(
                f"Tensor byte-size mismatch for {name} in {path.name}: "
                f"offsets={end - start}, dtype/shape={expected_tensor_bytes}"
            )
        if name in tensors:
            raise ValidationError(f"Duplicate tensor name within {path.name}: {name}")

        tensors[name] = {
            "shard": path.name,
            "dtype": dtype,
            "shape": shape,
            "start": start,
            "end": end,
            "bytes": end - start,
        }
        intervals.append((start, end, name))
        dtype_histogram[dtype] += 1
        tensor_bytes_by_dtype[dtype] += end - start

    cursor = 0
    gap_bytes = 0
    for start, end, name in sorted(intervals):
        if start < cursor:
            raise ValidationError(f"Overlapping tensor payload at {name} in {path.name}")
        gap_bytes += start - cursor
        cursor = end
    gap_bytes += payload_bytes - cursor

    summary = {
        "path": path.name,
        "file_bytes": file_bytes,
        "header_bytes": header_length,
        "header_sha256": sha256_hex(header_bytes),
        "payload_bytes": payload_bytes,
        "tensor_count": len(tensors),
        "dtype_histogram": dict(sorted(dtype_histogram.items())),
        "tensor_bytes_by_dtype": dict(sorted(tensor_bytes_by_dtype.items())),
        "unreferenced_payload_bytes": gap_bytes,
    }
    return tensors, summary


def validate_set(
    source_dir: Path,
    *,
    expected_tensor_count: int | None = None,
    expected_dtype: str | None = None,
    expected_total_size: int | None = None,
    require_zero_unreferenced: bool = False,
) -> dict[str, Any]:
    if not source_dir.is_dir() or source_dir.is_symlink() or is_reparse_point(source_dir):
        raise ValidationError(f"Source directory is not a plain directory: {source_dir}")

    index_path = source_dir / "model.safetensors.index.json"
    if not index_path.is_file() or index_path.is_symlink() or is_reparse_point(index_path):
        raise ValidationError("Index is not a plain file")
    with index_path.open("r", encoding="utf-8", errors="strict") as stream:
        index = json.load(stream)
    if not isinstance(index, dict) or not isinstance(index.get("weight_map"), dict):
        raise ValidationError("Index lacks an object-valued weight_map")

    all_tensors: dict[str, dict[str, Any]] = {}
    shard_summaries: list[dict[str, Any]] = []
    aggregate_dtype_histogram: Counter[str] = Counter()
    aggregate_tensor_bytes: Counter[str] = Counter()

    for shard_name in EXPECTED_SHARDS:
        tensors, summary = validate_shard(source_dir / shard_name)
        overlap = sorted(set(all_tensors).intersection(tensors))
        if overlap:
            raise ValidationError(f"Tensor names occur in multiple shards: {overlap[:3]}")
        all_tensors.update(tensors)
        shard_summaries.append(summary)
        aggregate_dtype_histogram.update(summary["dtype_histogram"])
        aggregate_tensor_bytes.update(summary["tensor_bytes_by_dtype"])

    weight_map: dict[str, Any] = index["weight_map"]
    if set(weight_map) != set(all_tensors):
        missing = sorted(set(weight_map) - set(all_tensors))
        extra = sorted(set(all_tensors) - set(weight_map))
        raise ValidationError(
            f"Index/header tensor-set mismatch: missing_from_shards={missing[:3]}, "
            f"missing_from_index={extra[:3]}"
        )

    allowed_shards = set(EXPECTED_SHARDS)
    for tensor_name, shard_name in weight_map.items():
        if shard_name not in allowed_shards:
            raise ValidationError(f"Index references an unexpected shard: {shard_name}")
        if all_tensors[tensor_name]["shard"] != shard_name:
            raise ValidationError(
                f"Index maps {tensor_name} to {shard_name}, but header places it in "
                f"{all_tensors[tensor_name]['shard']}"
            )

    tensor_bytes = sum(entry["bytes"] for entry in all_tensors.values())
    metadata = index.get("metadata")
    if not isinstance(metadata, dict) or not isinstance(metadata.get("total_size"), int):
        raise ValidationError("Index lacks integer metadata.total_size")
    if metadata["total_size"] != tensor_bytes:
        raise ValidationError(
            f"Index total_size mismatch: index={metadata['total_size']}, headers={tensor_bytes}"
        )

    if expected_tensor_count is not None and len(all_tensors) != expected_tensor_count:
        raise ValidationError(
            f"Tensor-count mismatch: expected={expected_tensor_count}, actual={len(all_tensors)}"
        )
    if expected_total_size is not None and tensor_bytes != expected_total_size:
        raise ValidationError(
            f"Frozen tensor-byte mismatch: expected={expected_total_size}, actual={tensor_bytes}"
        )
    if expected_dtype is not None:
        expected_histogram = {expected_dtype: len(all_tensors)}
        actual_histogram = dict(sorted(aggregate_dtype_histogram.items()))
        if actual_histogram != expected_histogram:
            raise ValidationError(
                f"Frozen dtype histogram mismatch: expected={expected_histogram}, "
                f"actual={actual_histogram}"
            )
    if require_zero_unreferenced:
        gaps = {
            shard["path"]: shard["unreferenced_payload_bytes"]
            for shard in shard_summaries
            if shard["unreferenced_payload_bytes"] != 0
        }
        if gaps:
            raise ValidationError(f"Unreferenced safetensors payload bytes are prohibited: {gaps}")

    return {
        "valid": True,
        "index": "model.safetensors.index.json",
        "expected_shards": list(EXPECTED_SHARDS),
        "tensor_count": len(all_tensors),
        "tensor_bytes": tensor_bytes,
        "index_total_size": metadata["total_size"],
        "dtype_histogram": dict(sorted(aggregate_dtype_histogram.items())),
        "tensor_bytes_by_dtype": dict(sorted(aggregate_tensor_bytes.items())),
        "shards": shard_summaries,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--expected-tensor-count", type=int)
    parser.add_argument("--expected-dtype", choices=sorted(DTYPE_BYTES))
    parser.add_argument("--expected-total-size", type=int)
    parser.add_argument("--require-zero-unreferenced", action="store_true")
    args = parser.parse_args()
    try:
        result = validate_set(
            args.source_dir.resolve(strict=True),
            expected_tensor_count=args.expected_tensor_count,
            expected_dtype=args.expected_dtype,
            expected_total_size=args.expected_total_size,
            require_zero_unreferenced=args.require_zero_unreferenced,
        )
    except (OSError, ValueError, ValidationError, json.JSONDecodeError) as exc:
        print(json.dumps({"valid": False, "error": str(exc)}, sort_keys=True), file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
