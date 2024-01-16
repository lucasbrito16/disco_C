clear-host
# Nome do serviço que você deseja verificar e reiniciar
$serviceName = "MySQL80"
$maxAttempts = 3  # Número máximo de tentativas

# Função para verificar o status do serviço
function Check-ServiceStatus {
    param (
        [string]$service
    )

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $status = Get-Service -Name $service | Select-Object -ExpandProperty Status
        Write-Host "Tentativa $attempt - Status do serviço ${service}: $status"

        if ($status -eq 'Running') {
            Write-Host "O serviço está em execução. Retornando status 'ok'."
            return 'ok'
        } else {
            Write-Host "O serviço não está em execução. Reiniciando o serviço."
            
            # Suprimindo a mensagem de aviso durante o reinício do serviço
            $null = Restart-Service -Name $service -WarningAction SilentlyContinue
            
            Start-Sleep -Seconds 10
        }
    }

    # Se ainda estiver aqui após as tentativas, algo deu errado
    Write-Host "A automação não foi bem-sucedida após $maxAttempts tentativas. Acione o time responsável para verificar."
    return 'falha'
}

# Bloco Try/Catch
try {
    # Chamada da função
    $status = Check-ServiceStatus -service $serviceName
    Write-Host "Status da automação: $status"
}
catch {
    Write-Host "Ocorreu um erro: $_"
}
