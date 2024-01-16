param (
    [string]$file1,
    [string]$dir1,
    [string]$file2,
    [string]$dir2,
    [string]$file3,
    [string]$dir3
)

function Check-FileExistence {
    param (
        [string]$file,
        [string]$dir
    )

    $filePath = Join-Path $dir $file

    if (Test-Path $filePath -PathType Leaf) {
        Write-Host "O arquivo $file existe no diretório $dir."
    } else {
        Write-Host "O arquivo $file NÃO existe no diretório $dir."
    }
}

# Verificando a existência dos arquivos nos diretórios especificados
Check-FileExistence -file $file1 -dir $dir1
Check-FileExistence -file $file2 -dir $dir2
Check-FileExistence -file $file3 -dir $dir3
