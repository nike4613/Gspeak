
$steamBase = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Valve\Steam).InstallPath;
Write-Debug "Found Steam installation at $steamBase";
$libsVdf = "$steamBase\steamapps\libraryfolders.vdf";

$vdf = Get-Content $libsVdf;
$searchBaseDirs = @();
$searchBaseDirs += $vdf |
  Select-String '"\d+".+"(.+)"' |
  ForEach-Object { $_.Matches.Groups[1].Value } |
  ForEach-Object { $_.Replace("\\","\") };
$searchBaseDirs += $steamBase;

$searchDirs = $searchBaseDirs | ForEach-Object { "$_\steamapps" };

foreach ($path in $searchDirs) {
  $file = "$path\appmanifest_4000.acf";
  if (-Not (Test-Path $file -PathType Leaf)) {
    continue;
  }

  $dirname = Get-Content $file |
    Select-String '"installdir".+"(.+)"' |
    ForEach-Object { $_.Matches.Groups[1].Value };

  $realdir = "$path\common\$dirname\"
  return $realdir;
}

Write-Error "Could not locate Garry's Mod installation directory"
