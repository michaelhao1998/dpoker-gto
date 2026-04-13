$ErrorActionPreference = "Stop"
$b = [System.IO.File]::ReadAllBytes('C:\Users\michaellhao\CodeBuddy\DPoker\prototype\index.html')
$s = [System.Text.Encoding]::UTF8.GetString($b)
$i = $s.IndexOf('FACING_ACTIONS')
if ($i -lt 0) { Write-Output "NOT FOUND"; exit 1 }
Write-Output "FOUND at $i"
Write-Output "---RAW---"
Write-Output ($s.Substring($i, 400))
Write-Output "---HEX---"
$hex = [System.Text.Encoding]::UTF8.GetBytes($s.Substring($i, 200)) | ForEach-Object { '{0:X2}' -f $_ }
Write-Output ($hex -join ' ')
