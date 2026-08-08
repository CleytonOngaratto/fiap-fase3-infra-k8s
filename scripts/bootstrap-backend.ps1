<#
.SYNOPSIS
    Cria o bucket S3 do state remoto e gera o backend.hcl local. Rode uma vez por conta.

.DESCRIPTION
    Os repos de infra (2, 3 e 5) compartilham o mesmo bucket, cada um com sua `key`.

.EXAMPLE
    .\scripts\bootstrap-backend.ps1
#>

[CmdletBinding()]
param(
    [string]$Region = "us-east-1",
    [string]$StateKey = "infra-k8s/terraform.tfstate"
)

$ErrorActionPreference = "Stop"

$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Sem credenciais validas. Abra a sessao do Learner Lab primeiro." }

$bucket = "fiap-fase3-tfstate-$($identity.Account)"
Write-Host "Conta $($identity.Account) · bucket alvo: $bucket" -ForegroundColor Cyan

# list-buckets e nao head-bucket: o head-bucket escreve um 404 em stderr quando o bucket ainda nao
# existe, que aparece em vermelho e parece falha sendo o caminho normal da primeira execucao.
$existente = aws s3api list-buckets --query "Buckets[?Name=='$bucket'].Name" --output text
if ($existente -eq $bucket) {
    Write-Host "Bucket ja existe — nada a criar." -ForegroundColor Green
}
else {
    # us-east-1 NAO aceita LocationConstraint: a API rejeita.
    if ($Region -eq "us-east-1") {
        $null = aws s3api create-bucket --bucket $bucket --region $Region
    }
    else {
        $null = aws s3api create-bucket --bucket $bucket --region $Region --create-bucket-configuration "LocationConstraint=$Region"
    }
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar o bucket $bucket." }

    $null = aws s3api put-bucket-versioning --bucket $bucket --versioning-configuration "Status=Enabled"

    $null = aws s3api put-public-access-block --bucket $bucket `
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    Write-Host "Bucket criado, versionado e fechado para acesso publico." -ForegroundColor Green
}

$backendPath = Join-Path (Split-Path $PSScriptRoot -Parent) "backend.hcl"
@"
# Gerado por scripts/bootstrap-backend.ps1 — NAO versionar (depende da conta do lab).
# Uso: terraform init "-backend-config=backend.hcl"
bucket       = "$bucket"
key          = "$StateKey"
region       = "$Region"
use_lockfile = true
encrypt      = true
"@ | Out-File -FilePath $backendPath -Encoding utf8

Write-Host "backend.hcl escrito em $backendPath" -ForegroundColor Green
Write-Host ""
Write-Host "Proximo passo:  terraform init `"-backend-config=backend.hcl`"" -ForegroundColor Cyan
Write-Host "No GitHub, cadastre a variable TF_STATE_BUCKET = $bucket nos repos de infra." -ForegroundColor Cyan
