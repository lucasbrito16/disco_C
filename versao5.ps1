Clear-Host
$DiskName = "C:\"
$DiskId = "C:"
$threshold = "5,01"

$DontClear = "C:\WINDOWS", "C:\PROGRAM FILES", "C:\PROGRAM FILES (x86)", "C:\ProgramData", "C:\reskitsup\PERFLog_SSID," , "C:\bginfo"
#$Global:totalSizeGB = ""

function AppendTrace {
    param (
        [string]$String
    )

    $TimeStamp = Get-Date -Format T
    Write-Host "-----------------------------------------------"
    Write-Host "$TimeStamp - $String"
}

function AppendMensagem {
    param (
    [string]$String
    )
    $TimeStamp = Get-Date -Format T
    Write-Host "-----------------------------------------------"
    Write-Host "$TimeStamp - $String"

}

function Check-FileExistence {
    param (
        [string]$file,
        [string]$dir
    )

    $filePath = Join-Path $dir $file

    if (Test-Path $filePath -PathType Leaf) {
        return "true"
    }
    else {
        return "false"
    }
}

function GetDiskInfo {
    param ([string]$DiskId
    )

    $diskInfo = Get-WmiObject -Query "SELECT * FROM Win32_LogicalDisk WHERE DeviceId='$DiskId'"
    if ($diskInfo -ne $null) {
        $totalSizeGb = $diskInfo.Size / 1GB
        $usedSpaceGB = ($diskInfo.Size - $diskInfo.FreeSpace) / 1GB
        $freeSpaceGB = $diskInfo.FreeSpace / 1GB

        $formattedTotalSize = "{0:F3}" -f $totalSizeGb
        $formattedUsedSpace = "{0:F3}" -f $usedSpaceGB
        $formattedFreeSpace = "{0:F3}" -f $freeSpaceGB

        $DiskInfoReturn =
        [pscustomobject]@{
            TotalSizeGb = $totalSizeGb
            UsedSpaceGB = $usedSpaceGB
            FreeSpaceGB = $freeSpaceGB
            FormattedTotalSize = $formattedTotalSize
            FormattedUsedSpace = $formattedUsedSpace
            FormattedFreeSpace = $formattedFreeSpace
        }
        return $DiskInfoReturn
    }

}


function LimpaLogsIIS {
    Set_location $diretorio
    AppendTrace "Executando limpeza, etapas:"
    try {
        try {
            Unblock-File IISLogManagement.ps1
        }
        catch {
            $retorno = "ERROS ENCONTRADOS AO EXECUTAR O COMANDO UNBLOCK-FILE - $($error[0])"
        }
        $retorno =& powershell -NoProfile -NonInteractive -Command "& { & './IISLog_Management.ps1' }" 2>$null 4>$null 6>$null
        if ($retorno -eq $null){
            $retorno = "NULL"
        }
    }
    catch {
        $retorno = "ERROS ENCONTRADOS AO EXECUTAR O IISLog_Management.ps1 - $($error[0])"
    }
    return $retorno
}

function Get-TimeElapsed {
    param (
        [datetime]$StartDate,
        [datetime]$EndDate
    )

    #Calcula o tempo decorrido
    $timeElapsed = $EndDate - $StartDate

    #mostra o tempo decorrido em dias, horas, minutos e segundos
    $days = $timeElapsed.Days
    $hours = $timeElapsed.Hours
    $minutes = $timeElapsed.Minutes
    $seconds = $timeElapsed.Seconds

    AppendTrace "Script executado em: $days dias, $hours horas, $minutes minutos, $seconds segundos"
}

function DiskStats($disco) {
    $Get = Get-WmiObject Win32_LogicalDisk | Where-Object { $_DeviceID -eq $disco } | Select-Object DeviceID, VolumeName, @{ Name = "SizeGB" ; Expression = { "0:N2}" -f ( $_.Size / 1gb) + " GB" } }, @{ Name = "GBLivre" ; Expression = { "{0:N2}" -f ($_.Freespace / 1gb ) + " GB" } }, @{ Name = "PercentFree" ; Expression = { "{0:P2}" -f ( $_.FreeSpace / $_.Size ) } }, Freespace, Size
    $TimeStamp = Get-Date -Format T
    $Disco = New-Object PSObject
    $Disco | Add-Member -Name Hora -MemberType NoteProperty -Value $TimeStamp
    $Disco | Add-Member -Name Letra -MemberType NoteProperty -Value $Get.DeviceID
    $Disco | Add-Member -Name Label -MemberType NoteProperty -Value $Get.VolumeName
    $Disco | Add-Member -Name GBTotal -MemberType NoteProperty -Value $Get.SizeGB
    $Disco | Add-Member -Name GBLivre -MemberType NoteProperty -Value $Get.GBLivre
    $Disco | Add-Member -Name Threshold -MemberType NoteProperty -Value (($Get.Size) /20)
    $Disco | Add-Member -Name BLivre -MemberType NoteProperty -Value $Get.Freespace
}

function GetSubDirectories {
    param (
        [string]$SubDirFullPath,
        [ref]$SubFolders,
        $totalSizeGB
    )

    $subOffenders = Get-ChildItem -Path $SubDirFullPath -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Hidden -or $_.Attributes -band [System.IO.FileAttributes]::Directory } | ForEach-Object {
        [pscustomobject]@{
            FullPath = $_.FullName
            Size = (Get-ChildItem -Recurse -File -Path $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
        }
    } | Sort-Object -Property Size -Descending
        
    foreach ($subFolder in $subOffenders) {
        $formattedSize = "{0:F3}" -f $subFolder.Size
        $SizePct = ($subFolder.Size / $totalSizeGB) *100
        $formattedSizePct = "{0:F3}" -f $SizePct

        $subFolders.Value += [pscustomobject]{ FullPath = $subFolder.FulPath ; Size = $subFolder.Size ; SizePct = $formattedSizePct }

    }
 }

 function GetDirectories {
    param (
        [string]$RootPath,
        [ref]$allFolders,
        $totalSizeGB
    )

    $mainFolders = Get-ChildItem -Path $RootPath -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Hidden -or $_.Attributes -band [System.IO.FileAttributes]::Directory } | ForEach-Object {
        [pscustomobject]@{
            FullPath = $_.FullName
            Size = (Get-ChildItem -Recurse -File -Path $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
        }
    } | Sort-Object -Property Size -Descending
        
    foreach ($mainFolder in $mainFolders) {
        $formattedSize = "{0:F3}" -f $mainFolder.Size
        $SizePct = ($mainFolder.Size / $totalSizeGB) *100
        $formattedSizePct = "{0:F3}" -f $SizePct

        $allFolders.Value += [pscustomobject]{ FullPath = $mainFolder.FulPath ; Size = $mainFolder.Size ; SizePct = $formattedSizePct }
    }
 }

 function CheckPERFLog_SSID {
    param (
        [ref]$allFolders,
        $totalSizeGB
    )

    $Check_PERFLog_SSID_Size = (Get-ChildItem -Path "C:\Reskitsup\PERFLog_SSID" -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
            
    $SizePct = ($Check_PERFLog_SSID_Size / $totalSizeGB) *100
    $formattedSizePct = "{0:F3}" -f $SizePct

    $allFolders.Value += [pscustomobject]{ FullPath = "C:\Reskitsup\PERFLog_SSID" ; Size = $Check_PERFLog_SSID_Size ; SizePct = $formattedSizePct }
    
 }

 # INICIO DA AUTOMACAO
AppendTrace "Inicio da Automacao"

$VerificarOfensores = ""
$StartDate = Get-Date
$allFolders = @()

AppendTrace "Coletando Informacoes do disco"
$Disk = GetDiskInfo -DiskId $DiskId

AppendTrace "Nome do Disco: C"
AppendTrace "Tamanho total do disco: $($Disk.FormattedTotalSize) GB"
AppendTrace "Espaco utilizado: $($Disk.FormattedUsedSpace) GB"
AppendTrace "Espaco livre: $($Disk.FormattedFreeSpace) GB"

$status_antes = DiskStats "C:"

if ($env:COMPUTERNAME.Contains("SCRTP") -or $env:COMPUTERNAME.Contains("SERTP")) {
    AppendTrace "Servidor é do tipo Terminal Server: Tentando realizar limpeza de Profile/Documents and Settings"

    $file1 = "limpa_profile.bat"
    $dir1 = "C:\RESKITSUP\Limpeza de Disco\LimpaProfile\"
    $dir2 = "C:\RESKITSUP\Limpeza de Disco\"
    $dir3 = "C:\RESKITSUP\"
    $dir4 = "C:\RESKITSUP\LimpaProfile\"

    AppendTrace "Verificando o caminho C:\RESKITSUP\Limpeza de Disco\LimpaProfile\"
    $retorno1 = Check-FileExistence -file $file1 -dir $dir1

    if ($retorno1 = "true") {
        AppendTrace "Arquivo de limpeza encontrado, realizando limpeza"
        #Executa Bat
        Start-Process -FilePath "C:\RESKITSUP\Limpeza de Disco\LimpaProfile\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
    }
    else {
        AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\Limpeza de Disco\"
        $retorno2 = Check-FileExistence -file $file1 -dir $dir2
        if ($retorno2 = "true") {
            #Executa Bat
            Start-Process -FilePath "C:\RESKITSUP\Limpeza de Disco\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
        }
        else {
            AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\"
            $retorno3 = Check-FileExistence -file $file1 -dir $dir3
            if ($retorno3 = "true") {
                #Executa Bat
                Start-Process -FilePath "C:\RESKITSUP\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
            }
            else {
                AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\LimpaProfile\"
                $retorno4 = Check-FileExistence -file $file1 -dir $dir4
                if ($retorno4 = "true") {
                    #Executa Bat
                    Start-Process -FilePath "C:\RESKITSUP\LimpaProfile\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
                }
                else {
                    AppendTrace "Arquivo de limpeza nao encontrado me nenhum dos diretorios, limpeza de profile nao executada"

                }
            }
        }
    }
    $status_depois = DiskStats "C:"
    $livre = $status_depois.PCTLivre -split '%'

    if ([single]$livre[0] -le [single]$threshold) {
        AppendTrace "Limpeza de profile executada com sucesso. Espaco livre antes da limpeza: $($status_antes.GBLivre)($($status_antes.PCTLivre)) - Espaco livre depois da limpeza: $($status_depois.GBLivre)($($status_depois.PCTLivre))"
        $status = "OK"
        $categoria = "SUCESSO"
        AppendMensagem "Limpeza de profile executada com sucesso. Espaco livre antes da limpeza: $($status_antes.GBLivre)($($status_antes.PCTLivre)) - Espaco livre depois da limpeza: $($status_depois.GBLivre)($($status_depois.PCTLivre))"
        AppendTrace "Finalizado"
        $VerificarOfensores = "false"
    }
    else {
        AppendTrace "Limpeza de Profile Executada, mas nao foi liberado espaco suficiente"
        $VerificarOfensores = "true"

    }
}
else {
    AppendTrace "Servidor nao e do tipo Terminal Server"
    $VerificarOfensores = "true"
}

if ($VerificarOfensores = "true") {
    
    #coletando os ofensores no disco C
    AppendTrace "Coletando diretórios que ocupam ao menos 5% de espaco no disco C:"

    GetDirectories -RootPath $DiskName 


 }









