# Script para solucionar el problema de secretos existentes
# Este script importa los secretos al estado de Terraform de forma correcta

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Solucion: Secretos Existentes" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$devPath = Join-Path $PSScriptRoot "envs\dev"
Set-Location $devPath

Write-Host "SOLUCION: Los secretos ya existen en AWS." -ForegroundColor Yellow
Write-Host "Terraform necesita importarlos al estado o actualizarlos.`n" -ForegroundColor White

Write-Host "OPCION 1: Importar secretos manualmente (RECOMENDADO)" -ForegroundColor Cyan
Write-Host "Ejecuta estos comandos uno por uno:" -ForegroundColor White
Write-Host ""
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]' 'genius/dev/database/credentials'" -ForegroundColor Gray
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.api_keys[0]' 'genius/dev/app/api-keys'" -ForegroundColor Gray
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.app_secrets[\"jwt_secret\"]' 'genius/dev/app/jwt_secret'" -ForegroundColor Gray
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.app_secrets[\"encryption_key\"]' 'genius/dev/app/encryption_key'" -ForegroundColor Gray
Write-Host ""

Write-Host "OPCION 2: Usar terraform apply con -replace (si la opcion 1 falla)" -ForegroundColor Cyan
Write-Host "Esto forzara a Terraform a actualizar los secretos existentes:" -ForegroundColor White
Write-Host ""
Write-Host "terraform apply -replace='module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]' -replace='module.secrets_manager.aws_secretsmanager_secret.api_keys[0]' -replace='module.secrets_manager.aws_secretsmanager_secret.app_secrets[\"jwt_secret\"]' -replace='module.secrets_manager.aws_secretsmanager_secret.app_secrets[\"encryption_key\"]'" -ForegroundColor Gray
Write-Host ""

Write-Host "OPCION 3: Eliminar secretos y recrearlos (PERDERAS EL CONTENIDO)" -ForegroundColor Red
Write-Host "Solo si no necesitas el contenido actual de los secretos:" -ForegroundColor White
Write-Host ""
Write-Host "cd infra" -ForegroundColor Gray
Write-Host ".\gestionar-secretos-eliminados.ps1" -ForegroundColor Gray
Write-Host "# Selecciona opcion 2: Forzar eliminacion inmediata" -ForegroundColor Gray
Write-Host ""

Write-Host "¿Quieres que ejecute la OPCION 1 ahora? (S/N):" -ForegroundColor Cyan
$confirm = Read-Host

if ($confirm -eq "S" -or $confirm -eq "s") {
    Write-Host "`nImportando secretos...`n" -ForegroundColor Yellow
    
    $imports = @(
        @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]"; ID = "genius/dev/database/credentials" },
        @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.api_keys[0]"; ID = "genius/dev/app/api-keys" },
        @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"jwt_secret`"]"; ID = "genius/dev/app/jwt_secret" },
        @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"encryption_key`"]"; ID = "genius/dev/app/encryption_key" }
    )
    
    foreach ($import in $imports) {
        Write-Host "Importando: $($import.ID)..." -ForegroundColor Cyan
        $output = & terraform import $import.Resource $import.ID 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Importado" -ForegroundColor Green
        } else {
            $outputText = $output -join [Environment]::NewLine
            if ($outputText -match "already managed" -or $outputText -match "already in state") {
                Write-Host "  [INFO] Ya esta en el estado" -ForegroundColor Yellow
            } else {
                Write-Host "  [ERROR] Ver error arriba" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`n[OK] Proceso completado. Ejecuta 'terraform apply' ahora." -ForegroundColor Green
} else {
    Write-Host "`nEjecuta manualmente los comandos de la OPCION 1 cuando estes listo." -ForegroundColor Yellow
}
