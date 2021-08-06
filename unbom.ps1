param (
    [Parameter()]
    [string]
    $File
)

$MyRawString = Get-Content -Raw $File
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($File, $MyRawString.Trim(), $Utf8NoBomEncoding)