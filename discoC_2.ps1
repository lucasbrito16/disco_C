clear-host
# Caminho do diretório raiz a ser verificado (no caso, C:\)
$diretorioRaiz = "C:\"

# Obtém a lista de diretórios no diretório raiz (incluindo diretórios ocultos)
$subdiretorios = Get-ChildItem -Path $diretorioRaiz -Directory -Force -ErrorAction SilentlyContinue

# Calcula o tamanho total do diretório raiz em GB
$tamanhoTotalRaiz = [math]::Round((Get-ChildItem -Path $diretorioRaiz -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB, 2)

# Calcula o tamanho de cada subdiretório no diretório raiz (até dois níveis) e converte para GB
$resultados = $subdiretorios | ForEach-Object {
    $tamanhoGB = [math]::Round((Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB, 2)

    [PSCustomObject]@{
        Diretorio = $_.FullName
        TamanhoGB  = $tamanhoGB
    }
}

# Adiciona mais um nível de subdiretórios
$subdiretoriosNivel2 = $subdiretorios | Get-ChildItem -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $tamanhoGB = [math]::Round((Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB, 2)

    [PSCustomObject]@{
        Diretorio = $_.FullName
        TamanhoGB  = $tamanhoGB
    }
}

# Concatena os resultados dos dois níveis
$resultados += $subdiretoriosNivel2

# Ordena os resultados pelo tamanho em ordem decrescente
$resultados = $resultados | Sort-Object -Property TamanhoGB -Descending

# Exibe o tamanho total do diretório raiz
Write-Host "Espaço total consumido no diretório raiz: ${tamanhoTotalRaiz} GB`n"

# Exibe apenas os 20 maiores subdiretórios em forma de lista
$top20 = $resultados | Select-Object -First 20 | ForEach-Object {
    "Diretório: $($_.Diretorio) | Tamanho: $($_.TamanhoGB) GB"
}

$top20 | Format-List

