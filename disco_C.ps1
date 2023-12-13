Clear-Host

function Get-SizeInfo {
    param(
        [parameter(mandatory=$true, position=1)]
        [string]$targetFolder,

        [parameter(mandatory=$true, position=2)]
        [int]$DepthLimit
    )

    $obj = New-Object psobject -Property @{Name=$targetFolder; Size=0; Subs=@()}

    if ($DepthLimit -eq 1) {
        $obj.Size = (Get-ChildItem $targetFolder -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Sum -Property Length).Sum
        return $obj
    }

    $obj.Subs = foreach ($S in Get-ChildItem $targetFolder -Force -ErrorAction SilentlyContinue) {
        if ($S.PSIsContainer) {
            $tmp = Get-SizeInfo $S.FullName ($DepthLimit - 1)
            $obj.Size += $tmp.Size
            Write-Output $tmp
        } else {
            $obj.Size += $S.Length
        }
    }

    return $obj
}

function Print-ResultsToFile {
    param(
        [parameter(mandatory=$true, position=1)]
        $Data,

        [parameter(mandatory=$true, position=2)]
        [string]$FilePath
    )

    $sortedSubs = $Data.Subs | Sort-Object -Property Size -Descending

    $output = "{0:N2} GB {1}" -f ($Data.Size / 1GB), $Data.Name
    Add-Content -Path $FilePath -Value $output

    foreach ($S in $sortedSubs) {
        Print-ResultsToFile $S $FilePath
    }
}

function Get-AllFolderSizes {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true, position=1)]
        [string]$targetFolder,

        [int]$DepthLimit = 3
    )

    if (-not (Test-Path $targetFolder)) {
        Write-Error "The target [$targetFolder] does not exist"
        exit
    }

    $Data = Get-SizeInfo $targetFolder $DepthLimit
    $FilePath = "C:\temp\lista.txt"
    
    # Delete the file if it exists
    Remove-Item -Path $FilePath -ErrorAction SilentlyContinue
    
    Print-ResultsToFile $Data $FilePath

    # Sort the file by size in descending order and get the top 20 lines
$sortedLines = Get-Content -Path $FilePath | ForEach-Object {
    [PSCustomObject]@{
        Line = $_
        Size = ($_ -split ' ')[0] -as [double]
    }
} | Sort-Object -Property Size -Descending | Select-Object -First 20 | ForEach-Object { $_.Line }

# Display the sorted top 20 lines
$sortedLines



}

Get-AllFolderSizes "C:\"
