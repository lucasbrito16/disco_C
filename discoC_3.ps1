Clear-Host
$DiskName = "C:\"
$DiskId = "C:"

function AppendTrace {
    param (
        [string]$String
    )

    $TimeStamp = Get-Date -format T
    Write-Host "$TimeStamp - $String `r`n"
}

function Get-TimeElapsed {
    param (
        [datetime]$StartDate,
        [datetime]$EndDate
    )

    # Calcula o tempo decorrido
    $timeElapsed = $EndDate - $StartDate

    # Mostra o tempo decorrido em dias, horas, minutos e segundos
    $days = $timeElapsed.Days
    $hours = $timeElapsed.Hours
    $minutes = $timeElapsed.Minutes
    $seconds = $timeElapsed.Seconds

    Write-Host "Script executado em: $days dias, $hours horas, $minutes minutos, $seconds segundos."
}

function GetDiskInfo {
    param (
        [string]$DiskId
    )

    $diskInfo = Get-WmiObject -Query "SELECT * FROM Win32_LogicalDisk WHERE DeviceID='$DiskId'"

    if ($diskInfo -ne $null) {
        $totalSizeGB = $diskInfo.Size / 1GB
        $usedSpaceGB = ($diskInfo.Size - $diskInfo.FreeSpace) / 1GB
        $freeSpaceGB = $diskInfo.FreeSpace / 1GB

        $formattedTotalSize = "{0:F3}" -f $totalSizeGB
        $formattedUsedSpace = "{0:F3}" -f $usedSpaceGB
        $formattedFreeSpace = "{0:F3}" -f $freeSpaceGB

        AppendTrace "Tamanho total do disco ${DiskId}: $($formattedTotalSize) GB"
        AppendTrace "Espaço utilizado: $($formattedUsedSpace) GB"
        AppendTrace "Espaço livre: $($formattedFreeSpace) GB"
    }
}

function GetSubDirectories {
    param (
        [string]$SubDirFullPath,
        [ref]$allFolders
    )

    $subFolders = Get-ChildItem -Path $SubDirFullPath -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Hidden -or $_.Attributes -band [System.IO.FileAttributes]::Directory } | ForEach-Object {
        [pscustomobject]@{
            FullPath = $_.FullName
            Size = (Get-ChildItem -Recurse -File -Path $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
        }
    } | Sort-Object -Property Size -Descending

    foreach ($subFolder in $subFolders) {
        $formattedSize = "{0:F3}" -f $subFolder.Size
        Write-Host "$($subFolder.FullPath): $($formattedSize) GB"
        $allFolders.Value += [pscustomobject]@{ FullPath = $subFolder.FullPath; Size = $subFolder.Size }
    }
}

function GetDirectories {
    param (
        [string]$RootPath,
        [ref]$allFolders
    )

    $mainFolders = Get-ChildItem -Path $RootPath -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Hidden -or $_.Attributes -band [System.IO.FileAttributes]::Directory } | ForEach-Object {
        [pscustomobject]@{
            FullPath = $_.FullName
            Size = (Get-ChildItem -Recurse -File -Path $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
        }
    } | Sort-Object -Property Size -Descending

    foreach ($mainFolder in $mainFolders) {
        $formattedSize = "{0:F3}" -f $mainFolder.Size
        Write-Host "$($mainFolder.FullPath): $($formattedSize) GB"
        $allFolders.Value += [pscustomobject]@{ FullPath = $mainFolder.FullPath; Size = $mainFolder.Size }
        GetSubDirectories -SubDirFullPath $mainFolder.FullPath -allFolders $allFolders
    }
}

# INICIO DA AUTOMACAO
AppendTrace "Inicio da Automação"
AppendTrace "Coletando informações do disco"
AppendTrace "Nome do disco: $DiskName"

#horario de inicio do script
$startDate = Get-Date

# Inicializando o array que será preenchido com os diretórios ofensores
$allFolders = @()

# Obtendo informações do disco C:
GetDiskInfo -DiskId $DiskId

# Coletando os ofensores no disco C
AppendTrace "Coletando diretórios que ocupam mais espaço no disco $DiskId"
GetDirectories -RootPath $DiskName -allFolders ([ref]$allFolders)

# Mostrando todos os diretórios e subdiretórios em ordem decrescente de tamanho
Write-Host "`nTodos os diretórios e subdiretórios ordenados por tamanho:"
$allFolders | Sort-Object -Property @{Expression={$_.Size}; Descending=$true} | Select-Object -First 20 | ForEach-Object {
    $formattedSize = "{0:F3}" -f $_.Size
    Write-Host "$($_.FullPath): $($formattedSize) GB"
    #Write-Host "$_"
}

$endDate = Get-Date
Get-TimeElapsed -StartDate $startDate -EndDate $endDate
