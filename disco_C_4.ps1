Clear-Host
$DiskName = "C:\"
$DiskId = "C:"

$DontClear = "C:\WINDOWS", "C:\PROGRAM FILES", "C:\ PROGRAM FILES (x86)", "C:\ProgramData", "C:\reskitsup\PERFLog_SSID", "C:\bginfo"
$Global:totalSizeGB = ""

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

    AppendTrace "Script executado em: $days dias, $hours horas, $minutes minutos, $seconds segundos."
}

function GetDiskInfo {
    param (
        [string]$DiskId
    )

    $diskInfo = Get-WmiObject -Query "SELECT * FROM Win32_LogicalDisk WHERE DeviceID='$DiskId'"

    if ($diskInfo -ne $null) {
        $Global:totalSizeGB = $diskInfo.Size / 1GB
        $usedSpaceGB = ($diskInfo.Size - $diskInfo.FreeSpace) / 1GB
        $freeSpaceGB = $diskInfo.FreeSpace / 1GB

        $formattedTotalSize = "{0:F3}" -f $totalSizeGB
        $formattedUsedSpace = "{0:F3}" -f $usedSpaceGB
        $formattedFreeSpace = "{0:F3}" -f $freeSpaceGB

        AppendTrace "Tamanho total do disco C: $($formattedTotalSize) GB"
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
        $SizePct = ($subFolder.Size / $Global:totalSizeGB) * 100
        $formattedSizePct = "{0:F3}" -f $SizePct
        #Write-Host "$($subFolder.FullPath): $($formattedSize) GB"
        $allFolders.Value += [pscustomobject]@{ FullPath = $subFolder.FullPath; Size = $subFolder.Size ; SizePct = $formattedSizePct}
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
        #Write-Host "$($mainFolder.FullPath): $($formattedSize) GB"
        $SizePct = ($mainFolder.Size / $Global:totalSizeGB) *100
        $formattedSizePct = "{0:F3}" -f $SizePct
        #write-host $SizePct
        $allFolders.Value += [pscustomobject]@{ FullPath = $mainFolder.FullPath; Size = $mainFolder.Size ; SizePct = $formattedSizePct}
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
AppendTrace "Coletando diretórios que ocupam ao menos 5% de espaço no disco C:"
GetDirectories -RootPath $DiskName -allFolders ([ref]$allFolders)

#$offenders = $allFolders | Sort-Object -Property @{Expression={$_.Size}; Descending=$true} | Select-Object { $_.SizePct -ge 5 } 
$offenders = $allFolders | Sort-Object -Property @{Expression={$_.Size}; Descending=$true} | Select-Object -First 20 

# Mostrando todos os diretórios e subdiretórios em ordem decrescente de tamanho
#Write-Host "`nTodos os diretórios e subdiretórios ordenados por tamanho:"
$offenders | ForEach-Object {
    $formattedSize = "{0:F3}" -f $_.Size
    AppendTrace "$($_.FullPath): $($formattedSize) GB ($($_.SizePct)%)"
    #Write-Host "$_"
}

#calcula o tempo que levou para coletar o espaço consumido pelos diretórios no disco C
$endDate = Get-Date
Get-TimeElapsed -StartDate $startDate -EndDate $endDate






#verifica se o serviço do IIS está instalado e executando no servidor
$iisService = Get-Service -Name W3SVC -ErrorAction SilentlyContinue

#se o IIS estiver instalado e rodando, entra aqui
if ($iisServiceRunning -ne $null -and $iisServiceRunning.Status -eq 'Running') {
    #verifica qual o diretório utilizado para salvar os logs do IIS
    $dirLogsIIS = Get-WebConfigurationProperty -Filter "/system.applicationHost/sites/siteDefaults/logfile" -Name directory | Select-Object -ExpandProperty Value
    AppendTrace "O IIS está instalado e o serviço está rodando. Os logs estão armazenados em $dirLogsIIS"
    }
else {
    AppendTrace "IIS não instalado no servidor."

}

#adiciona os logs do IIS aos diretórios que podem ser ofensores
$DontClear.Add($dirLogsIIS)




# Verificar se algum elemento de $DontClear está presente em $allFolders
$conflictingFolders = $allFolders | Where-Object { $DontClear -contains $_.FullPath }

# Se houver algum conflito, mostrar a mensagem
if ($conflictingFolders.Count -gt 0) {
    Write-Host "`nDiretórios que não devem ser removidos:`n"
    $conflictingFolders | ForEach-Object {
        Write-Host $_.FullPath
    }
} else {
    Write-Host "`nNenhum conflito encontrado. Pode prosseguir com a limpeza se necessário."










