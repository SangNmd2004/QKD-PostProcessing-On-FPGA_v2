param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Prompt
)

$python = "C:/msys64/mingw64/bin/python3.12.exe"
$scriptPath = Join-Path $PSScriptRoot "agent_chat.py"

if (-not (Test-Path $scriptPath)) {
    throw "Cannot find agent_chat.py in $PSScriptRoot"
}

if ($Prompt.Count -gt 0) {
    & $python $scriptPath @Prompt
}
else {
    & $python $scriptPath
}