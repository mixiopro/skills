#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

run_render() {
    bash "$INSTALLER" --render-public-agents-doc "$1" "$2" >/dev/null
}

assert_file_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if ! cmp -s "$expected" "$actual"; then
        printf 'Expected and actual files differ for %s:\n' "$message" >&2
        diff -u "$expected" "$actual" >&2 || true
        fail "$message"
    fi
}

assert_contains() {
    local file="$1"
    local text="$2"

    grep -Fq -- "$text" "$file" || fail "missing '$text' in $file"
}

assert_not_contains() {
    local file="$1"
    local text="$2"

    ! grep -Fq -- "$text" "$file" || fail "unexpected '$text' in $file"
}

assert_rejected_without_changing_destination() {
    local source="$1"
    local destination="$2"
    local before="$3"
    local label="$4"

    if run_render "$source" "$destination"; then
        fail "$label was accepted"
    fi
    assert_file_equals "$before" "$destination" "$label preserved its destination"
}

# A legacy source has no managed block. The no-block path must preserve bytes,
# including the absence of a final newline.
legacy_source="$TEST_ROOT/legacy-source.md"
legacy_expected="$TEST_ROOT/legacy-expected.md"
legacy_destination="$TEST_ROOT/legacy-destination.md"
printf '%s' $'# Production guidance\n\nKeep this exact.\nLast line without newline' > "$legacy_source"
printf '%s' $'# Production guidance\n\nKeep this exact.\nLast line without newline' > "$legacy_expected"
run_render "$legacy_source" "$legacy_destination"
assert_file_equals "$legacy_expected" "$legacy_destination" 'legacy source without a block'

write_valid_case() {
    local version="$1"
    local source="$2"
    local expected="$3"

    printf '%s\n' \
        '# Production guidance before' \
        '' \
        "<!-- BEGIN MIXIO TRACKING $version -->" \
        'private contributor instructions' \
        '<!-- END MIXIO TRACKING -->' \
        '' \
        '# Production guidance after' > "$source"
    printf '%s\n' \
        '# Production guidance before' \
        '' \
        '' \
        '# Production guidance after' > "$expected"
}

# Both the previous and current versioned marker forms are valid and only the
# managed block is removed.
old_source="$TEST_ROOT/old-source.md"
old_expected="$TEST_ROOT/old-expected.md"
old_destination="$TEST_ROOT/old-destination.md"
write_valid_case 'v2026-09-11.1' "$old_source" "$old_expected"
run_render "$old_source" "$old_destination"
assert_file_equals "$old_expected" "$old_destination" 'old valid managed block'
assert_not_contains "$old_destination" 'MIXIO TRACKING'
assert_not_contains "$old_destination" 'private contributor instructions'

current_source="$TEST_ROOT/current-source.md"
current_expected="$TEST_ROOT/current-expected.md"
current_destination="$TEST_ROOT/current-destination.md"
write_valid_case 'v2026-09-12.1' "$current_source" "$current_expected"
run_render "$current_source" "$current_destination"
assert_file_equals "$current_expected" "$current_destination" 'current valid managed block'
assert_not_contains "$current_destination" 'MIXIO TRACKING'
assert_not_contains "$current_destination" 'private contributor instructions'

# Replacing an existing document and repeating the same render must produce
# exactly the same public bytes.
printf '%s\n' 'previous installed document' > "$current_destination"
run_render "$current_source" "$current_destination"
assert_file_equals "$current_expected" "$current_destination" 'replace an existing document'
run_render "$current_source" "$current_destination"
assert_file_equals "$current_expected" "$current_destination" 'repeat public document rendering'

# A valid block must not change whether surrounding production content ends in
# a newline.
unterminated_source="$TEST_ROOT/unterminated-source.md"
unterminated_expected="$TEST_ROOT/unterminated-expected.md"
unterminated_destination="$TEST_ROOT/unterminated-destination.md"
printf '%s' $'# Production guidance before\n<!-- BEGIN MIXIO TRACKING v2026-09-11.2 -->\nprivate contributor instructions\n<!-- END MIXIO TRACKING -->\n# Production guidance after' > "$unterminated_source"
printf '%s' $'# Production guidance before\n# Production guidance after' > "$unterminated_expected"
run_render "$unterminated_source" "$unterminated_destination"
assert_file_equals "$unterminated_expected" "$unterminated_destination" 'valid block with unterminated production content'

# Count bytes rather than characters, and preserve CRLF plus the missing final
# newline when the source comes from a Windows or macOS checkout.
crlf_source="$TEST_ROOT/crlf-source.md"
crlf_expected="$TEST_ROOT/crlf-expected.md"
crlf_destination="$TEST_ROOT/crlf-destination.md"
printf '%s' $'# Production caf\xc3\xa9\r\n<!-- BEGIN MIXIO TRACKING v2026-09-12.1 -->\r\nprivate contributor instructions\r\n<!-- END MIXIO TRACKING -->\r\nKeep \xe2\x9c\x93 without newline' > "$crlf_source"
printf '%s' $'# Production caf\xc3\xa9\r\nKeep \xe2\x9c\x93 without newline' > "$crlf_expected"
run_render "$crlf_source" "$crlf_destination"
assert_file_equals "$crlf_expected" "$crlf_destination" 'UTF-8 and CRLF production bytes'

# Exercise the checked-in source at test time so concurrent source updates are
# observed without modifying AGENTS.md.
checked_in_destination="$TEST_ROOT/checked-in-destination.md"
run_render "$REPO_ROOT/AGENTS.md" "$checked_in_destination"
assert_contains "$checked_in_destination" '## Resolve scope before doing anything (required)'
assert_contains "$checked_in_destination" '## Conventions'
assert_not_contains "$checked_in_destination" '<!-- BEGIN MIXIO TRACKING'
assert_not_contains "$checked_in_destination" '<!-- END MIXIO TRACKING -->'

# An incomplete block is rejected before the destination is replaced.
missing_end_source="$TEST_ROOT/missing-end-source.md"
missing_end_destination="$TEST_ROOT/missing-end-destination.md"
missing_end_before="$TEST_ROOT/missing-end-before.md"
printf '%s\n' \
    '# Production guidance' \
    '<!-- BEGIN MIXIO TRACKING v2026-09-11.2 -->' \
    'private contributor instructions' > "$missing_end_source"
printf '%s\n' 'keep existing destination' > "$missing_end_destination"
cp "$missing_end_destination" "$missing_end_before"
assert_rejected_without_changing_destination \
    "$missing_end_source" "$missing_end_destination" "$missing_end_before" 'incomplete managed block'

# Two otherwise valid blocks are rejected rather than partially stripped.
duplicate_source="$TEST_ROOT/duplicate-source.md"
duplicate_destination="$TEST_ROOT/duplicate-destination.md"
duplicate_before="$TEST_ROOT/duplicate-before.md"
write_valid_case 'v2026-09-11.1' "$duplicate_source" "$TEST_ROOT/unused-expected.md"
printf '%s\n' \
    '<!-- BEGIN MIXIO TRACKING v2026-09-11.2 -->' \
    'second private contributor instructions' \
    '<!-- END MIXIO TRACKING -->' >> "$duplicate_source"
printf '%s\n' 'keep duplicate destination' > "$duplicate_destination"
cp "$duplicate_destination" "$duplicate_before"
assert_rejected_without_changing_destination \
    "$duplicate_source" "$duplicate_destination" "$duplicate_before" 'duplicate managed blocks'

# An unversioned marker is malformed and must not be treated as production
# content or silently copied.
malformed_source="$TEST_ROOT/malformed-source.md"
malformed_destination="$TEST_ROOT/malformed-destination.md"
malformed_before="$TEST_ROOT/malformed-before.md"
printf '%s\n' \
    '# Production guidance' \
    '<!-- BEGIN MIXIO TRACKING -->' \
    'private contributor instructions' \
    '<!-- END MIXIO TRACKING -->' > "$malformed_source"
printf '%s\n' 'keep malformed destination' > "$malformed_destination"
cp "$malformed_destination" "$malformed_before"
assert_rejected_without_changing_destination \
    "$malformed_source" "$malformed_destination" "$malformed_before" 'unversioned managed marker'

# A directory is not an AGENTS document. Do not move a temporary output into it
# and claim that installation succeeded.
directory_destination="$TEST_ROOT/directory-destination"
mkdir "$directory_destination"
if run_render "$legacy_source" "$directory_destination"; then
    fail 'directory destination was accepted'
fi
[ -z "$(ls -A "$directory_destination")" ] || fail 'directory destination changed'

printf 'OK: public AGENTS.md rendering fixtures passed\n'
