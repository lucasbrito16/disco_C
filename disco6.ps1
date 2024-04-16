Clear-Host
$DiskName = "C:\"
$DiskId = "C:"
$threshold = "26,97"

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
    #Write-Host "-----------------------------------------------"
    #Write-Host "$TimeStamp - $String"

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
    $Get = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $disco } | Select-Object DeviceID, VolumeName, @{ Name = "SizeGB" ; Expression = { "{0:N2}" -f ( $_.Size / 1gb) + " GB" } }, @{ Name = "GBLivre" ; Expression = { "{0:N2}" -f ($_.Freespace / 1gb ) + " GB" } }, @{ Name = "PercentFree" ; Expression = { "{0:P2}" -f ( $_.FreeSpace / $_.Size ) } }, Freespace, Size
    $TimeStamp = Get-Date -Format T
    $Disco = New-Object PSObject
    $Disco | Add-Member -Name Hora -MemberType NoteProperty -Value $TimeStamp
    $Disco | Add-Member -Name Letra -MemberType NoteProperty -Value $Get.DeviceID
    $Disco | Add-Member -Name Label -MemberType NoteProperty -Value $Get.VolumeName
    $Disco | Add-Member -Name GBTotal -MemberType NoteProperty -Value $Get.SizeGB
    $Disco | Add-Member -Name GBLivre -MemberType NoteProperty -Value $Get.GBLivre
    $Disco | Add-Member -Name PCTLivre -MemberType NoteProperty -Value $Get.PercentFree
    return $Disco
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

        $subFolders.Value += [pscustomobject]@{ FullPath = $subFolder.FullPath ; Size = $subFolder.Size ; SizePct = $formattedSizePct }

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

        $allFolders.Value += [pscustomobject]@{ FullPath = $mainFolder.FullPath ; Size = $mainFolder.Size ; SizePct = $formattedSizePct }
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

    $allFolders.Value += [pscustomobject]@{ FullPath = "C:\Reskitsup\PERFLog_SSID" ; Size = $Check_PERFLog_SSID_Size ; SizePct = $formattedSizePct }
    
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

$computerName = $env:COMPUTERNAME

$computerName = "SCRTP"

if ($computerName.Contains("SCRTP") -or $computerName.Contains("SERTP")) {
    AppendTrace "Servidor é do tipo Terminal Server: Tentando realizar limpeza de Profile/Documents and Settings"

    $file1 = "limpa_profile.bat"
    $dir1 = "C:\RESKITSUP\Limpeza de Disco\LimpaProfile\"
    $dir2 = "C:\RESKITSUP\Limpeza de Disco\"
    $dir3 = "C:\RESKITSUP\"
    $dir4 = "C:\RESKITSUP\LimpaProfile\"

    AppendTrace "Verificando o caminho C:\RESKITSUP\Limpeza de Disco\LimpaProfile\"
    $retorno1 = Check-FileExistence -file $file1 -dir $dir1

    if ($retorno1 -eq "true") {
        AppendTrace "Arquivo de limpeza encontrado, realizando limpeza"
        #Executa Bat
        Start-Process -FilePath "C:\RESKITSUP\Limpeza de Disco\LimpaProfile\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
    }
    else {
        AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\Limpeza de Disco\"
        $retorno2 = Check-FileExistence -file $file1 -dir $dir2
        if ($retorno2 -eq "true") {
            #Executa Bat
            Start-Process -FilePath "C:\RESKITSUP\Limpeza de Disco\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
        }
        else {
            AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\"
            $retorno3 = Check-FileExistence -file $file1 -dir $dir3
            if ($retorno3 -eq "true") {
                #Executa Bat
                #$emptyPipeline = [System.Management.Automation.Runspaces.Pipeline]::Create()
                #Start-Process -FilePath "C:\RESKITSUP\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $emptyPipeline -RedirectStandardError $emptyPipeline
                $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processStartInfo.FileName = "C:\RESKITSUP\limpa_profile.bat"
                $processStartInfo.UseShellExecute = $false
                $processStartInfo.CreateNoWindow = $true

                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $processStartInfo
                $process.Start() | Out-Null
            }
            else {
                AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\LimpaProfile\"
                $retorno4 = Check-FileExistence -file $file1 -dir $dir4
                if ($retorno4 -eq "true") {
                    #Executa Bat
                    Start-Process -FilePath "C:\RESKITSUP\LimpaProfile\limpa_profile.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
                }
                else {
                    AppendTrace "Arquivo de limpeza nao encontrado me nenhum dos diretorios, limpeza de profile nao executada"

                }
            }
        }
    }
    sleep 1
    $status_depois = DiskStats "C:"
    $livre = $status_depois.PCTLivre -split '%'

    if ([single]$livre[0] -ge [single]$threshold) {
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

if ($VerificarOfensores -eq "true") {
    
    #coletando os ofensores no disco C
    AppendTrace "Coletando diretórios que ocupam ao menos 5% de espaco no disco C:"

    GetDirectories -RootPath $DiskName -allFolders ([ref]$allFolders) -totalSizeGB $Disk.TotalSizeGb
    CheckPERFLog_SSID -allFolders ([ref]$allFolders) -totalSizeGB $Disk.TotalSizeGb

    #Porcentagem minima do ofensor
    $MinnimumOffenderSize = [single]"1,000"

    #ofensores que ocupam pelo menos 5% no disco
    $offenders = $allFolders | Where-Object { [single]$_.SizePct -ge [single]$MinnimumOffenderSize } | Sort-Object -Property @{Expression = {$_.Size}; Descending = $true}

    if (!($offenders -eq $null)) {
        
        #mostrando todos os ofensores
        $offenders | ForEach-Object {
            $formattedSize = "{0:F3}" -f $_.Size
            AppendTrace "$($_.FullPath): $($formattedSize) GB ($($_.SizerPct)%)"
        }

    #verifica se o serviço do IIS está instalado e executando no servidor
    $iisService = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
    AppendTrace "Verificando se o servidor possui IIS instalado"
    
    if ($iisService -ne $null -and $iisService.Status -eq 'Running') {
        #verifica qual o diretorio para salvar os logs
        $dirLogsIIS = Get-WebConfigurationProperty -Filter "/system.applicationHost/sites/siteDefaults/logfile" -Name directory | Select-Object - ExpandProperty Value
        AppendTrace "O IIS esta instalado e o servico esta rodando. Os logs estao armazenados em $dirLogsIIS"
    }
    else {
        AppendTrace "IIS nao instalado no servidor ou nao esta em execucao"
        $dirLogsIIS = "nao tem IIS"
    }

    #verificacao dos ofensores
    AppendTrace "Analisando ofensores"

    $MaiorOfensor = $offenders[0].FullPath.ToUpper()
    $NumeroOfensores = $offenders.Length

    #maior ofensor é Windows

    if ($MaiorOfensor -eq "C:\WINDOWS") {
        #Se ocupar menos de 50GB precisa verificar o segundo ofensor
        if ($offenders[0].Size -lt "50,000") {
            AppendTrace "O maior ofensor e C:\WINDOWS, mas possui menos de 50GB. Verificando proximo ofensor"
            AppendMensagem "O maior ofensor e C:\WINDOWS, mas possui menos de 50GB. Verificando proximo ofensor"
            #verifica se existe outro ofensor
            if ($NumeroOfensores -gt "1") {
                $verificaOutros = "SIM"
                $ProximoOfensor = $offenders[1].FullPath.ToUpper()
            }
            else {
                AppendTrace "O unico ofensor e C:\WINDOWS e esta utilizando $offenders[0].Size , necessario acionar o time Suporte Windows"
                AppendMensagem "O unico ofensor e C:\WINDOWS e esta utilizando $offenders[0].Size , necessario acionar o time Suporte Windows"
                $verificaOutros = "NAO"
            }
        }
        else {
            AppendTrace "O unico ofensor e C:\WINDOWS e ocuma mais de 50GB , necessario acionar o time Suporte Windows"
            AppendMensagem "O unico ofensor e C:\WINDOWS e ocuma mais de 50GB , necessario acionar o time Suporte Windows"
            $verificaOutros = "NAO"
        }
    }

    #maior ofensor nao é windows, mas é um destes
    elseif (($MaiorOfensor -eq "C:\RESKITSUP\PERFLOG_SSID") -or ($MaiorOfensor -eq "C:\RESKITSUP") -or ($MaiorOfensor -eq "C:\SCOM") -or ($MaiorOfensor -eq "C:\USERS") -or ($MaiorOfensor -eq $dirLogsIIS.ToUpper())) {
        AppendTrace "O maior ofensor e $MaiorOfensor"
        AppendMensagem "O maior ofensor e $MaiorOfensor"
        $verificaOutros = "SIM"
        $ProximoOfensor = $MaiorOfensor
    }
    #ofensores nao mapeados
    else {
        AppendTrace "O maior ofensor e $MaiorOfensor , necessario realizar a limpeza de logs de aplicacao"
        AppendMensagem "O maior ofensor e $MaiorOfensor , necessario realizar a limpeza de logs de aplicacao"
        $verificaOutros = "SIM"
        $ProximoOfensor = $MaiorOfensor
    }
    }
    else {
        AppendTrace "Nenhum ofensor encontrado. Direcionando o incidente para a Operacao Distribuida"
        AppendMensagem "Nenhum ofensor encontrado. Direcionando o incidente para a Operacao Distribuida"
        $verificaOutros = "NAO"
    }
}
else {
    AppendTrace "Nao ha necessidade de verificar os ofensores"
    AppendMensagem "Nao ha necessidade de verificar os ofensores"
    $verificaOutros = "NAO"
}

if ($verificaOutros -eq "SIM") {

    if (($ProximoOfensor -eq "C:\RESKITSUP\PERFLOG_SSID") -or ($ProximoOfensor -eq "C:\RESKITSUP")){
        AppendTrace "O Ofensor e $ProximoOfensor e nao pode ser limpo, necessario direcionar o incidente para o time Suporte Windows"
        $status = "NOK"
        $categoria = "DIRECIONAR"
        AppendMensagem "O Ofensor e $ProximoOfensor e nao pode ser limpo, necessario direcionar o incidente para o time Suporte Windows"
    }
    elseif ($ProximoOfensor -eq "C:\SCOM") {
        AppendTrace "O Ofensor e $ProximoOfensor e nao pode ser limpo, necessario acionar o time de monitoração distribuida"
        $status = "NOK"
        $categoria = "ACIONAR"
        AppendMensagem "O Ofensor e $ProximoOfensor e nao pode ser limpo, necessario acionar o time de monitoração distribuida"
    }
    elseif ($ProximoOfensor -eq $dirLogsIIS.ToUpper()) {
        AppendTrace "O Ofensor e $ProximoOfensor e nao pode ser limpo, necessario realizar a limpeza de logs do IIS"
        AppendMensagem "O Ofensor e $ProximoOfensor e nao pode ser limpo, necessario realizar a limpeza de logs do IIS"

        $fileIIS = "IISLogManagement.ps1"
        $dirIIS = "C:\ReskitSUP\"

        AppendTrace "Verificando o arquivo de limpeza"
        $retornoIIS = Check-FileExistence -file $fileIIS -dir $dirIIS

        if ($retornoIIS = "true") {
            AppendTrace "Arquivo de limpeza encontrado, realizando limpeza"
            #Limpeza IIS
            $saida = LimpaLogsIIS $dirIIS
            if ($saida -ne "NULL") {
                AppendTrace "$saida"
                if ($saida.Contains("ERRO")) {
                    AppendTrace "Houve erros ao executar o C:\ReskitSUP\IISLog_Management.ps1"
                }
            }
            if ($saida -eq "NULL") {
                AppendTrace "Script de limpeza retornou NULL"
            }

            AppendTrace "Verificando espaco livre apos a limpeza:"
            $status_depois = DiskStats "C:" 
            AppendTrace "Espaco livre apos a limpeza - $($status_depois.GBLivre) Livre/ $($status_depois.PCTLivre) Livres."
            $livre_depois = $status_depois.PCTLivre -split '%'
            if ([single]$livre_depois[0] -le [single]$threshold) {
                AppendTrace "Limpeza executada, mas o disco ainda nao possui espaco livre suficiente. Direcionar o incidente para o time responsavel para alterarem os Logs do IIS do Disco C para o Disco L"
                $status = "NOK"
                $categoria = "REGRA"
                AppendMensagem "Limpeza executada, mas o disco ainda nao possui espaco livre suficiente. Direcionar o incidente para o time responsavel para alterarem os Logs do IIS do Disco C para o Disco L"
            }
            else {
                AppendTrace "Limpeza executada, o disco possui espaco livre suficiente. Direcionar o incidente para o time responsavel para alterarem os Logs do IIS do Disco C para o Disco L"
                $status = "NOK"
                $categoria = "REGRA"
                AppendMensagem "Limpeza executada, o disco possui espaco livre suficiente. Direcionar o incidente para o time responsavel para alterarem os Logs do IIS do Disco C para o Disco L"
            }
        }
        else {
            AppendTrace "Arquivo de limpeza nao encontrado, necessario realizar a limpeza manualmente"
            $status = "NOK"
            $categoria = "REGRA"
            AppendMensagem "Arquivo de limpeza nao encontrado, necessario realizar a limpeza manualmente e solicitar para o time responsavel para alterarem os Logs do IIS do Disco C para o Disco L"
        }
    }
    elseif ($ProximoOfensor -eq "C:\USERS") {
        AppendTrace "Ofensor e $ProximoOfensor . verificando subpasta ofensora"
        AppendMensagem "Ofensor e $ProximoOfensor . verificando subpasta ofensora"

        $subFolders = @()

        GetSubDirectories -SubDirFullPath "C:\USERS" -SubFolders ([ref]$subFolders) -totalSizeGB $Disk.TotalSizeGB

        #Filtrando os ofensores
        $offendersSubDir = $subFolders | Sort-Object -Property @{Expression = { $_.Size }; Descending = $true }

        if (!($offendersSubDir -eq $null)) {
            AppendTrace "O ofensor e $($offendersSubDir[0].FullPath), necessario direcionar o incidente para o time responsavel verificar o ofensor"
            $status = "NOK"
            $categoria = "REGRA"
            AppendMensagem "O ofensor e $($offendersSubDir[0].FullPath), necessario direcionar o incidente para o time responsavel verificar o ofensor"
        }
        else {
            AppendTrace "O ofensor e C:\USERS, necessario direcionar o incidente para o time responsavel verificar o ofensor"
            $status = "NOK"
            $categoria = "REGRA"
            AppendMensagem "O ofensor e C:\USERS, necessario direcionar o incidente para o time responsavel verificar o ofensor"
        }
    }

    else {
        
        AppendTrace "O ofensor e $ProximoOfensor , tentando realizar a limpeza dos logs de aplicacao"

        $so = (Get-WmiObject win32_operatingsystem).name
        AppendTrace "Versao do SO: $so"

        $fileLogsAppAntes2008 = "Limpa_Disco_win2k3.bat"
        $fileLogsAppDepois2008 = "Limpa_Disco_win2k8.bat"
        $dirLogsApp1 = "C:\RESKITSUP\Limpeza de Disco\"
        $dirLogsApp2 = "C:\RESKITSUP\"

        #se o sistema for superior a windows server 2008
        if(($so -notmatch '2003') -and ($s0 -notmatch '2008')) {

            AppendTrace "Verificando o caminho C:\RESKITSUP\Limpeza de Disco\ "
            $retornoLogsApp1 = Check-FileExistence -file $fileLogsAppDepois2008 -dir $dirLogsApp1

            if ($retornoLogsApp1 -eq "true") {
                AppendTrace "Arquivo de limpeza encontrado, realizando limpeza"

                #Executa Bat
                Start-Process -FilePath "C:\RESKITSUP\Limpeza de Disco\Limpa_Disco_win2k8.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
            }
            else {
                AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\"

                $retornoLogsApp2 = Check-FileExistence -file $fileLogsAppDepois2008 -dir $dirLogsApp2
                if ($retornoLogsApp2 -eq "true") {
                    AppendTrace "Arquivo de limpeza encontrado, realizando limpeza"

                    #Executa Bat
                    Start-Process -FilePath "C:\RESKITSUP\Limpa_Disco_win2k8.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
                }
                else {
                    AppendTrace "Arquivos de limpeza nao encnotrados, necessario direcionar o incidente para o grupo responsavel analisar o ofensor"
                }

            }
            


        }

        #sistema inferior a windows server 2008
        else {

            AppendTrace "Verificando o caminho C:\RESKITSUP\Limpeza de Disco\ "
            $retornoLogsApp1 = Check-FileExistence -file $fileLogsAppAntes2008 -dir $dirLogsApp1

            if ($retornoLogsApp1 -eq "true") {
                AppendTrace "Arquivo de limpeza encontrado, realizando limpeza"

                #Executa Bat
                Start-Process -FilePath "C:\RESKITSUP\Limpeza de Disco\Limpa_Disco_win2k3.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
            }
            else {
                AppendTrace "Arquivo de limpeza nao encontrado, verificando o caminho C:\RESKITSUP\"

                $retornoLogsApp2 = Check-FileExistence -file $fileLogsAppAntes2008 -dir $dirLogsApp2
                if ($retornoLogsApp2 -eq "true") {
                    AppendTrace "Arquivo de limpeza encontrado, realizando limpeza"

                    #Executa Bat
                    Start-Process -FilePath "C:\RESKITSUP\Limpa_Disco_win2k3.bat" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null
                }
                else {
                    AppendTrace "Arquivos de limpeza nao encnotrados, necessario direcionar o incidente para o grupo responsavel analisar o ofensor"
                }
            }
        }
    }
}

else {
    AppendTrace "Nao ha outros ofensores"
}

#calcula o tempo de execucao do script
$endDate = Get-Date

Get-TimeElapsed -StartDate $StartDate -EndDate $endDate







