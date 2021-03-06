$exclusions = Get-Content .\keep.exl
$gameVers = Read-Host "Please enter game version:"
if (Test-Path "./TempAssemblies/") {
 
    Write-Host "Folder Exists"
    Remove-Item "./TempAssemblies/" -Recurse -Force -Confirm:$false
}

if (Test-Path "./toZip/") {
 
    Write-Host "Folder Exists"
    Remove-Item "./toZip/" -Recurse -Force -Confirm:$false
}

New-Item './TempAssemblies/' -ItemType "directory"
New-Item './toZip/' -ItemType "directory"
New-Item './toZip/Assemblies/' -ItemType "directory"
Copy-Item 'C:\Program Files (x86)\Steam\steamapps\common\Bigscreen\MelonLoader\Managed\*' -Destination './TempAssemblies/' -Recurse
dir './TempAssemblies/' | Where-Object { $exclusions -notcontains $_.name } | Remove-Item
Copy-Item './TempAssemblies/**' -Destination './toZip/Assemblies/' -Recurse
"These assemblies are for the following game version:

$gameVers

They are dummy DLLs and cannot be used to run the game.
Check the modding guide for infomation on how to reference these DLLs in Visual Studio" | Out-File -FilePath './toZip/readme.txt' -Encoding 'UTF-8' 

$compress = @{
    Path = "./toZip/*"
    CompressionLevel = "Fastest"
    DestinationPath = "./$gameVers.zip"
  }

Compress-Archive @compress

$token = $Env:github_token
$Env:github_token | Write-Output 
$tag = $gameVers
$name = $gameVers
$descr = "**DevKit for ``$gameVers``**

For infomation on what the DevKit is, [checkout the Bigscreen Modding Guide here.](https://cal117.gitbook.io/bsmg/)

*Automatically Generated, ping ``@cal117#2214`` on discord if there are any mistakes or errors.*
"
$user = "BigscreenModded"
$project = "DevKit"
$file = "C:\Users\rb01px\dev\Bigscreen\DevKit Tools\$gameVers.zip"

$auth = @{"Authorization"="token $token"}
$files = $file.Split("|")

function UploadAsset([int]$rel_id,[string]$fullpath)
{
  #$rel_id = 528606

  $type_7z  = "application/octet-stream"
  $type_exe = "application/x-msdownload"

  $fname = Split-Path $fullpath -Leaf

  if ([System.IO.Path]::GetExtension($fname) -eq ".7z") {
    $content_type = $type_7z
  } else {
    $content_type = $type_exe
  }
  $rel_arg = $auth + @{"Content-Type"=$content_type; "name"=$fname;}
  $rel_arg_js = ConvertTo-Json $rel_arg

  Write-Host "Loading contents of '$fullpath'"
  #$body = Get-Content -Encoding byte -Path $fullpath
  $body = [System.IO.File]::ReadAllBytes($fullpath)

  #$content_type = "application/x-www-form-urlencoded"

  Write-Host "  -Uri 'https://uploads.github.com/repos/$user/$project/releases/$rel_id/assets?name=$fname'"
  Write-Host -NoNewLine "  -Headers "
  $rel_arg

  Write-Host "  Uploading to github"
  $rel = Invoke-WebRequest -Headers $rel_arg -Method POST -Body $body -Uri https://uploads.github.com/repos/$user/$project/releases/$rel_id/assets?name=$fname

  Write-Host "  Upload finished, checking result"
  if (($rel -eq $null) -Or ($rel.StatusCode -ne 201)) {
    $rel
    $host.SetShouldExit(101)
    exit
  }

  $rel_js = ConvertFrom-Json $rel.Content
  # $rel_js
  Write-Host ("  Upload is ready for download: " + $rel_js.browser_download_url)
}

function FindAsset([int]$rel_id,[string]$fullpath)
{
  $fname = Split-Path $fullpath -Leaf
  $a_id = 0
  $rel = Invoke-WebRequest -Headers $auth -Uri https://api.github.com/repos/$user/$project/releases/$rel_id/assets
  if ($rel -eq $null) {
    return 0
  }
  $rel_js = ConvertFrom-Json $rel.Content
  $rel_js | where {$_.name -eq $fname} | foreach {
    $a_id = $_.id
    Write-Host "Asset $fname was already uploaded, id: $a_id"
    Write-Host ("  Upload is ready for download: " + $_.browser_download_url)
  }
  return $a_id
}

function FindRelease([string]$tag_name)
{
  $rel_id = 0
  $rel = Invoke-WebRequest -Headers $auth -Uri https://api.github.com/repos/$user/$project/releases
  if ($rel -eq $null) {
    return 0
  }
  $rel_js = ConvertFrom-Json $rel.Content
  $rel_js | where {$_.tag_name -eq $tag_name} | foreach {
    $rel_id = $_.id
    Write-Host ("Release found, upload_url=" + $_.upload_url)
  }
  return $rel_id
}

function CreateRelease([string]$tag,[string]$name,[string]$descr)
{
  #  "target_commitish"="60b20ba"; `
  #  "target_commitish"="master"; `
  #  "target_commitish"="daily"; `

  #$tag_name = ("v"+$build.Substring(0,2)+"."+$build.Substring(2,2)+"."+$build.Substring(4))
  #$tag_name = $tag

  #Write-Host "$tag $name $descr"

  $rel_arg = @{ `
    "tag_name"=$tag; `
    "name"=$name; `
    "body"=$descr; `
    "draft"=$FALSE; `
    "prerelease"=$FALSE
  }

  $rel_arg_js = ConvertTo-Json $rel_arg
  #$rel_arg_js

  $rel = Invoke-WebRequest -Headers $auth -Method POST -Body $rel_arg_js -Uri https://api.github.com/repos/$user/$project/releases
  if ($rel -ne $null)
  {
    $rel_js = ConvertFrom-Json $rel.Content
    return $rel_js.id
  }

  $host.SetShouldExit(101)
  exit
}

Write-Host "Trying to find release $tag"
$rel_id = FindRelease $tag
if ($rel_id -ne 0) {
  Write-Host "Release already created, id: $rel_id"
} else {
  $rel_id = CreateRelease $tag $name $descr
  Write-Host "Release created, id: $rel_id"
}

$files | foreach {
  $a_id = FindAsset $rel_id $_
  if ($a_id -ne 0) {
    # Write-Host "Asset $_ was already uploaded, id: $a_id"
  } else {
    UploadAsset $rel_id $_
  }
}

Write-Host "Cleaning Up"
Remove-Item "./toZip/" -Recurse -Force -Confirm:$false
Remove-Item "./TempAssemblies/" -Recurse -Force -Confirm:$false
Remove-Item "./$gameVers.zip" -Force -Confirm:$false
