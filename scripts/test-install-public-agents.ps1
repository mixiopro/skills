$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $RepoRoot "install.ps1"
$TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mixio-public-agents-" + [System.Guid]::NewGuid().ToString("N"))

function Fail([string]$Message) {
    throw "FAIL: $Message"
}

function Get-Utf8Bytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [bool]$WithBom = $false
    )

    $encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList @($false)
    $body = $encoding.GetBytes($Text)
    if (-not $WithBom) {
        return ,$body
    }

    $bytes = New-Object -TypeName System.Byte[] -ArgumentList ($body.Length + 3)
    $bytes[0] = 0xEF
    $bytes[1] = 0xBB
    $bytes[2] = 0xBF
    [System.Array]::Copy($body, 0, $bytes, 3, $body.Length)
    return ,$bytes
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [bool]$WithBom = $false
    )

    $bytes = [byte[]](Get-Utf8Bytes -Text $Text -WithBom $WithBom)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

function Read-Utf8Text([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
    }
    $encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList @($false, $true)
    return $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
}

function Assert-BytesEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedPath,
        [Parameter(Mandatory = $true)]
        [string]$ActualPath,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $expected = [System.IO.File]::ReadAllBytes($ExpectedPath)
    $actual = [System.IO.File]::ReadAllBytes($ActualPath)
    if ($expected.Length -ne $actual.Length) {
        Fail "$Label changed byte length from $($expected.Length) to $($actual.Length)"
    }
    for ($index = 0; $index -lt $expected.Length; $index++) {
        if ($expected[$index] -ne $actual[$index]) {
            Fail "$Label differs at byte $index"
        }
    }
}

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Text,
        [string]$Label
    )

    if ((Read-Utf8Text $Path).IndexOf($Text, [System.StringComparison]::Ordinal) -lt 0) {
        Fail "$Label is missing '$Text'"
    }
}

function Assert-NotContains {
    param(
        [string]$Path,
        [string]$Text,
        [string]$Label
    )

    if ((Read-Utf8Text $Path).IndexOf($Text, [System.StringComparison]::Ordinal) -ge 0) {
        Fail "$Label unexpectedly contains '$Text'"
    }
}

function Assert-NoAdjacentTemp {
    param(
        [string]$Path,
        [string]$Label
    )

    $parent = Split-Path -Parent $Path
    $leaf = Split-Path -Leaf $Path
    $temps = @(Get-ChildItem -LiteralPath $parent -Filter (".{0}.*.tmp" -f $leaf) -Force -ErrorAction SilentlyContinue)
    if ($temps.Count -ne 0) {
        Fail "$Label left an adjacent temporary output"
    }
}

function Invoke-Render {
    param(
        [string]$Source,
        [string]$Destination
    )

    $messages = @()
    $succeeded = $true
    try {
        $messages = @(& $Installer -RenderPublicAgentsDoc -SourcePath $Source -DestinationPath $Destination 2>&1)
        if (-not $?) {
            $succeeded = $false
        }
    } catch {
        $succeeded = $false
        $messages += $_
    }

    return @{
        Succeeded = $succeeded
        Output = (($messages | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
    }
}

function Assert-RenderSucceeded {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Label
    )

    $result = Invoke-Render $Source $Destination
    if (-not $result.Succeeded) {
        Fail "$Label was rejected: $($result.Output)"
    }
    if (-not [string]::IsNullOrWhiteSpace($result.Output)) {
        Fail "$Label produced unexpected render-only output: $($result.Output)"
    }
    Assert-NoAdjacentTemp $Destination $Label
}

function Assert-RenderRejectedWithoutChangingDestination {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Before,
        [string]$Label
    )

    $result = Invoke-Render $Source $Destination
    if ($result.Succeeded) {
        Fail "$Label was accepted"
    }
    if ([string]::IsNullOrWhiteSpace($result.Output) -or $result.Output.IndexOf("MIXIO TRACKING", [System.StringComparison]::Ordinal) -lt 0) {
        Fail "$Label did not report a visible MIXIO TRACKING error"
    }
    Assert-BytesEqual $Before $Destination "$Label destination"
    Assert-NoAdjacentTemp $Destination "$Label"
}

try {
    [System.IO.Directory]::CreateDirectory($TestRoot) | Out-Null

    # Markerless legacy content is copied byte-for-byte, including CRLF,
    # Unicode content, and an unterminated final line.
    $legacySource = Join-Path $TestRoot "legacy-source.md"
    $legacyExpected = Join-Path $TestRoot "legacy-expected.md"
    $legacyDestination = Join-Path $TestRoot "legacy-destination.md"
    $legacyText = "# Production guidance`r`nKeep caf" + [char]0xE9 + " exact`r`nLast line without newline"
    Write-Utf8File $legacySource $legacyText
    Write-Utf8File $legacyExpected $legacyText
    Write-Utf8File $legacyDestination "replace this existing destination"
    Assert-RenderSucceeded $legacySource $legacyDestination "legacy source without a block"
    Assert-BytesEqual $legacyExpected $legacyDestination "legacy source without a block"
    Assert-RenderSucceeded $legacySource $legacyDestination "legacy source without a block (repeat)"
    Assert-BytesEqual $legacyExpected $legacyDestination "legacy source without a block (repeat)"

    # The prior versioned block is removed while surrounding LF production
    # content remains unchanged.
    $oldSource = Join-Path $TestRoot "old-source.md"
    $oldExpected = Join-Path $TestRoot "old-expected.md"
    $oldDestination = Join-Path $TestRoot "old-destination.md"
    $oldText = "# Production guidance before`n`n<!-- BEGIN MIXIO TRACKING v2026-09-11.1 -->`nprivate contributor instructions`n<!-- END MIXIO TRACKING -->`n`n# Production guidance after`n"
    $oldExpectedText = "# Production guidance before`n`n`n# Production guidance after`n"
    Write-Utf8File $oldSource $oldText
    Write-Utf8File $oldExpected $oldExpectedText
    Assert-RenderSucceeded $oldSource $oldDestination "old valid managed block"
    Assert-BytesEqual $oldExpected $oldDestination "old valid managed block"
    Assert-NotContains $oldDestination "MIXIO TRACKING" "old valid managed block"

    # The current versioned block is removed while CRLF and a UTF-8 BOM are
    # preserved in the output.
    $currentSource = Join-Path $TestRoot "current-source.md"
    $currentExpected = Join-Path $TestRoot "current-expected.md"
    $currentDestination = Join-Path $TestRoot "current-destination.md"
    $currentText = "# Production guidance before`r`n`r`n<!-- BEGIN MIXIO TRACKING v2026-09-12.1 -->`r`nprivate contributor instructions`r`n<!-- END MIXIO TRACKING -->`r`n`r`n# Production guidance after`r`n"
    $currentExpectedText = "# Production guidance before`r`n`r`n`r`n# Production guidance after`r`n"
    Write-Utf8File $currentSource $currentText $true
    Write-Utf8File $currentExpected $currentExpectedText $true
    Assert-RenderSucceeded $currentSource $currentDestination "current valid managed block"
    Assert-BytesEqual $currentExpected $currentDestination "current valid managed block"
    Assert-Contains $currentDestination "# Production guidance after" "current valid managed block"
    Assert-NotContains $currentDestination "MIXIO TRACKING" "current valid managed block"

    # Read the checked-in source at test time so concurrent AGENTS.md updates
    # are exercised without modifying that source file.
    $checkedInDestination = Join-Path $TestRoot "checked-in-destination.md"
    Assert-RenderSucceeded (Join-Path $RepoRoot "AGENTS.md") $checkedInDestination "checked-in AGENTS.md"
    Assert-Contains $checkedInDestination "## Resolve scope before doing anything (required)" "checked-in AGENTS.md"
    Assert-NotContains $checkedInDestination "<!-- BEGIN MIXIO TRACKING" "checked-in AGENTS.md"
    Assert-NotContains $checkedInDestination "<!-- END MIXIO TRACKING -->" "checked-in AGENTS.md"

    # An incomplete block is rejected visibly and leaves an existing
    # destination byte-for-byte unchanged.
    $missingEndSource = Join-Path $TestRoot "missing-end-source.md"
    $missingEndDestination = Join-Path $TestRoot "missing-end-destination.md"
    $missingEndBefore = Join-Path $TestRoot "missing-end-before.md"
    Write-Utf8File $missingEndSource "# Production guidance`r`n<!-- BEGIN MIXIO TRACKING v2026-09-11.2 -->`r`nprivate contributor instructions"
    Write-Utf8File $missingEndDestination "keep existing destination"
    [System.IO.File]::Copy($missingEndDestination, $missingEndBefore, $true)
    Assert-RenderRejectedWithoutChangingDestination $missingEndSource $missingEndDestination $missingEndBefore "incomplete managed block"

    # Two valid blocks are rejected rather than partially stripped.
    $duplicateSource = Join-Path $TestRoot "duplicate-source.md"
    $duplicateDestination = Join-Path $TestRoot "duplicate-destination.md"
    $duplicateBefore = Join-Path $TestRoot "duplicate-before.md"
    $duplicateText = "# Production guidance`n<!-- BEGIN MIXIO TRACKING v2026-09-11.1 -->`nfirst private instructions`n<!-- END MIXIO TRACKING -->`n<!-- BEGIN MIXIO TRACKING v2026-09-11.2 -->`nsecond private instructions`n<!-- END MIXIO TRACKING -->`n# Production after`n"
    Write-Utf8File $duplicateSource $duplicateText
    Write-Utf8File $duplicateDestination "keep duplicate destination"
    [System.IO.File]::Copy($duplicateDestination, $duplicateBefore, $true)
    Assert-RenderRejectedWithoutChangingDestination $duplicateSource $duplicateDestination $duplicateBefore "duplicate managed blocks"

    # Unversioned and stray markers are malformed, not production text.
    $malformedSource = Join-Path $TestRoot "malformed-source.md"
    $malformedDestination = Join-Path $TestRoot "malformed-destination.md"
    $malformedBefore = Join-Path $TestRoot "malformed-before.md"
    Write-Utf8File $malformedSource "# Production guidance`n<!-- BEGIN MIXIO TRACKING -->`nprivate contributor instructions`n<!-- END MIXIO TRACKING -->`n"
    Write-Utf8File $malformedDestination "keep malformed destination"
    [System.IO.File]::Copy($malformedDestination, $malformedBefore, $true)
    Assert-RenderRejectedWithoutChangingDestination $malformedSource $malformedDestination $malformedBefore "unversioned managed marker"

    $strayEndSource = Join-Path $TestRoot "stray-end-source.md"
    $strayEndDestination = Join-Path $TestRoot "stray-end-destination.md"
    $strayEndBefore = Join-Path $TestRoot "stray-end-before.md"
    Write-Utf8File $strayEndSource "# Production guidance`n<!-- END MIXIO TRACKING -->`n# Production after`n"
    Write-Utf8File $strayEndDestination "keep stray-end destination"
    [System.IO.File]::Copy($strayEndDestination, $strayEndBefore, $true)
    Assert-RenderRejectedWithoutChangingDestination $strayEndSource $strayEndDestination $strayEndBefore "stray managed end marker"

    Write-Output "OK: Windows public AGENTS.md rendering fixtures passed"
} finally {
    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
