criar .bat para deletar arquivos

@echo off
echo Removendo arquivos do diretório C:\Users\lucas\Desktop\APAGAR SEM MEDO
del "C:\Users\lucas\Desktop\APAGAR SEM MEDO\*.*" /q
echo Arquivos removidos com sucesso!
pause

criar arquivo grande:

fsutil file createnew test 10485760000

powershell para remover arquivos:

# Define o caminho do diretório a ser limpo
$directoryPath = "C:\caminho\para\seu\diretorio"

# Remove todos os arquivos do diretório especificado
Get-ChildItem -Path $directoryPath -File | Remove-Item -Force

# Remove todos os subdiretórios vazios do diretório especificado
Get-ChildItem -Path $directoryPath -Directory | Where-Object { $_.GetFileSystemInfos().Count -eq 0 } | Remove-Item -Force -Recurse

Write-Host "Arquivos e subdiretórios vazios removidos com sucesso!"
