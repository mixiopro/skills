"""Check workflow packet declarations and adjunct bundle triggers."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List
import sys

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parents[1]))

from scripts.lib import collect_asset_index, repo_root

def check_workflow_protocols(root: Path) -> Dict[str, Any]:
    root = root.resolve()
    _, assets, manifests, _ = collect_asset_index(root)
    errors: List[str] = []

    protocols = [a for a in assets if a["type"] == "workflow_protocol"]

    for proto in protocols:
        pid = proto["id"]
        atom_count = proto.get("mandatory_atom_count")
        linked = proto.get("linked_atoms", [])

        # Check mandatory_atom_count matches the packet declaration.
        if atom_count is None:
            errors.append(f"{pid}: missing mandatory_atom_count")
        elif atom_count != len(linked):
            errors.append(
                f"{pid}: mandatory_atom_count={atom_count} but linked_atoms has {len(linked)} items"
            )

        # Check expansion_allowed exists
        if "expansion_allowed" not in proto:
            errors.append(f"{pid}: missing expansion_allowed")

    # Check manifest adjunct_bundles reference valid constraint families
    for manifest in manifests:
        mid = manifest["id"]
        bundles = manifest.get("adjunct_bundles", {})
        for bundle_name, bundle_def in bundles.items():
            trigger = bundle_def.get("trigger", "")
            if not trigger:
                errors.append(f"{mid}: adjunct bundle '{bundle_name}' missing trigger")

    return {
        "errors": errors,
        "protocol_count": len(protocols),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=str(repo_root()))
    args = parser.parse_args()
    report = check_workflow_protocols(Path(args.root))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not report["errors"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
