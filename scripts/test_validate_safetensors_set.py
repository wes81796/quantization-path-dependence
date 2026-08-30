#!/usr/bin/env python3
"""Self-test the sharded-safetensors validator with valid and invalid fixtures."""

from __future__ import annotations

import json
import struct
import tempfile
from pathlib import Path

from validate_safetensors_set import EXPECTED_SHARDS, ValidationError, validate_set


def write_shard(path: Path, tensor_name: str) -> None:
    header = {
        "__metadata__": {"format": "pt"},
        tensor_name: {"dtype": "BF16", "shape": [1], "data_offsets": [0, 2]},
    }
    encoded = json.dumps(header, separators=(",", ":")).encode("utf-8")
    path.write_bytes(struct.pack("<Q", len(encoded)) + encoded + b"\x00\x00")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="qpd-safetensors-validator-") as temp:
        root = Path(temp)
        weight_map: dict[str, str] = {}
        for index, shard_name in enumerate(EXPECTED_SHARDS):
            tensor_name = f"tensor_{index}"
            write_shard(root / shard_name, tensor_name)
            weight_map[tensor_name] = shard_name

        index_path = root / "model.safetensors.index.json"
        index_path.write_text(
            json.dumps({"metadata": {"total_size": 6}, "weight_map": weight_map}),
            encoding="utf-8",
        )

        valid = validate_set(
            root,
            expected_tensor_count=3,
            expected_dtype="BF16",
            expected_total_size=6,
            require_zero_unreferenced=True,
        )
        assert valid["valid"] is True
        assert valid["tensor_count"] == 3
        assert valid["tensor_bytes"] == 6
        assert valid["dtype_histogram"] == {"BF16": 3}

        bad_map = dict(weight_map)
        bad_map["tensor_0"] = EXPECTED_SHARDS[1]
        index_path.write_text(
            json.dumps({"metadata": {"total_size": 6}, "weight_map": bad_map}),
            encoding="utf-8",
        )
        try:
            validate_set(root)
        except ValidationError:
            pass
        else:
            raise AssertionError("wrong-shard mapping fixture did not fail")

        write_shard(root / EXPECTED_SHARDS[0], "tensor_0")
        with (root / EXPECTED_SHARDS[0]).open("ab") as stream:
            stream.write(b"\x00")
        index_path.write_text(
            json.dumps({"metadata": {"total_size": 6}, "weight_map": weight_map}),
            encoding="utf-8",
        )
        try:
            validate_set(root, require_zero_unreferenced=True)
        except ValidationError:
            pass
        else:
            raise AssertionError("unreferenced-payload fixture did not fail")

    print(
        json.dumps(
            {
                "valid_fixture": "pass",
                "wrong_shard_fixture": "expected-failure-pass",
                "unreferenced_payload_fixture": "expected-failure-pass",
            }
        )
    )


if __name__ == "__main__":
    main()
