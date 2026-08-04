#!/usr/bin/env python3
"""Deterministic shot chunker for Step 05 of the Mixio pipeline.

Usage:
    python3 chunk.py 4.5 3.0 9.0 3.5 3.0     # chunk these durations
    python3 chunk.py                          # run the self-check

Rules (see SKILL.md): a chunk grows while total <= MAX_SECONDS and count < MAX_SHOTS.
The shot that would break either cap opens the next chunk. A shot longer than
MAX_SECONDS on its own becomes a flagged single-shot chunk.
"""
import sys

MAX_SECONDS = 15.0
MAX_SHOTS = 5
RAPID = {"RAPID", "PUNCHY"}


def chunk(durations):
    """Return (chunks, flagged) where chunks is a list of 1-based shot-number lists
    and flagged is the shot numbers whose own duration exceeds MAX_SECONDS."""
    chunks, flagged, current, total = [], [], [], 0.0
    for i, d in enumerate(durations, start=1):
        if d > MAX_SECONDS:
            if current:
                chunks.append(current)
            chunks.append([i])          # rule 4: own chunk, flagged
            flagged.append(i)
            current, total = [], 0.0
            continue
        if current and (total + d > MAX_SECONDS or len(current) >= MAX_SHOTS):
            chunks.append(current)      # rule 3: close, and this shot opens the next
            current, total = [], 0.0
        current.append(i)
        total += d
    if current:
        chunks.append(current)
    return chunks, flagged


def rapid_sections(chunks, pacing):
    """Chunk numbers (1-based) containing 3+ consecutive RAPID/PUNCHY shots."""
    out, run, hits = [], 0, set()
    for i, p in enumerate(pacing, start=1):
        run = run + 1 if str(p).upper() in RAPID else 0
        if run >= 3:
            hits.update(range(i - run + 1, i + 1))
    for n, c in enumerate(chunks, start=1):
        if len(hits.intersection(c)) >= 3:
            out.append(n)
    return out


def summary(durations, pacing=None):
    chunks, flagged = chunk(durations)
    lines = [
        "PRODUCTION SUMMARY",
        f"Total shots:     {len(durations)}",
        f"Total chunks:    {len(chunks)}",
        f"Total runtime:   {sum(durations):.1f}s",
        "Shots flagged over 15s: "
        + (", ".join(f"Shot {i} ({durations[i-1]:.1f}s)" for i in flagged) or "none"),
    ]
    if pacing:
        rs = rapid_sections(chunks, pacing)
        lines.append("Rapid pacing sections: "
                     + (", ".join(f"chunk {n}" for n in rs) or "none"))
    for n, c in enumerate(chunks, start=1):
        d = sum(durations[i - 1] for i in c)
        lines.append(f"  chunk {n}: shots {c[0]}-{c[-1]} "
                     f"({len(c)} shot{'s' if len(c) > 1 else ''}, {d:.1f}s)"
                     + ("  ** OVER 15s **" if c[0] in flagged else ""))
    return "\n".join(lines)


def _self_check():
    # worked example from SKILL.md
    assert chunk([4.5, 3.0, 9.0, 3.5, 3.0])[0] == [[1, 2], [3, 4], [5]]
    # exactly at the cap is allowed ("at or under 15")
    assert chunk([7.5, 7.5])[0] == [[1, 2]]
    assert chunk([7.5, 7.6])[0] == [[1], [2]]
    # shot-count cap bites before the duration cap
    assert chunk([1.0] * 6)[0] == [[1, 2, 3, 4, 5], [6]]
    # over-length shot: own chunk, flagged, and it does not swallow its neighbours
    assert chunk([2.0, 18.0, 2.0]) == ([[1], [2], [3]], [2])
    # an over-length shot mid-chunk closes the open chunk first, skipping nothing
    assert chunk([2.0, 2.0, 18.0, 2.0]) == ([[1, 2], [3], [4]], [3])
    # every shot lands in exactly one chunk, in order
    for ds in ([], [3.0], [4.5, 3.0, 9.0, 3.5, 3.0], [1.0] * 13, [20.0, 20.0]):
        flat = [i for c in chunk(ds)[0] for i in c]
        assert flat == list(range(1, len(ds) + 1)), ds
    # rapid pacing: 3 consecutive in one chunk flags it, 2 does not
    cs, _ = chunk([2.0] * 5)
    assert rapid_sections(cs, ["RAPID", "RAPID", "PUNCHY", "NORMAL", "NORMAL"]) == [1]
    assert rapid_sections(cs, ["RAPID", "RAPID", "NORMAL", "RAPID", "RAPID"]) == []
    print("chunk.py self-check passed")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(summary([float(a) for a in sys.argv[1:]]))
    else:
        _self_check()
