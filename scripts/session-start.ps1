<#
.SYNOPSIS
    Checklist de retomada de sessão do Learner Lab. Não provisiona nada — orienta e valida.

.DESCRIPTION
    A infra é destruída entre sessões porque o control plane do EKS cobra ~US$2,40/dia mesmo com o
    lab desligado. Toda retomada segue a mesma ordem, e este script a imprime e valida.

.EXAMPLE
    .\scripts\session-start.ps1
#>

[CmdletBinding()]
param([string]$Region = "us-east-1")

Write-Host @"

RETOMADA DE SESSAO — FIAP Fase 3
================================
Ordem obrigatoria de deploy: 2 (infra-k8s) -> 3 (infra-db) -> 4 (app) -> 1 (auth-serverless)
Tempo estimado ate conseguir demonstrar algo: ~35 min

  1. Abrir o lab e colar o bloco 'AWS Details' em ~/.aws/credentials         (~1 min)
  2. .\scripts\refresh-gh-secrets.ps1 -Org <org>   (se for usar o CI)        (~1 min)
  3. .\scripts\preflight.ps1                                                (~10 s)
  4. terraform init "-backend-config=backend.hcl" ; terraform apply         (~15 min)
  5. Repo 3: terraform apply (RDS)                                          (~10 min)
  6. Repo 4: pipeline build -> push ECR -> kubectl apply                     (~8 min)
  7. Repo 1: terraform apply (Lambda + API Gateway)                          (~2 min)

FIM DA SESSAO — destruir na ordem INVERSA: 1 -> 4 -> 3 -> 2
  (antes do repo 2: kubectl delete svc <do tipo LoadBalancer>, senao a ENI trava o destroy da VPC)

"@ -ForegroundColor Cyan

$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Sessao do lab NAO esta ativa. Comece pelo passo 1." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Sessao ativa — conta $($identity.Account)" -ForegroundColor Green

# Ja existe algo de pe? Evita subir um segundo cluster por engano (e o custo dobrado disso).
$clusters = aws eks list-clusters --region $Region --query "clusters" --output json | ConvertFrom-Json
if ($LASTEXITCODE -eq 0 -and $clusters.Count -gt 0) {
    Write-Host "[!] Ja existe cluster EKS na conta: $($clusters -join ', ')" -ForegroundColor Yellow
    Write-Host "    Se for da sessao anterior, ele esta faturando desde entao. Confira antes de aplicar de novo." -ForegroundColor Yellow
}
else {
    Write-Host "[OK] Nenhum cluster EKS de pe — comecando do zero, como esperado." -ForegroundColor Green
}

$params = aws ssm get-parameters-by-path --path /fase3 --recursive --region $Region --query "Parameters[].Name" --output json | ConvertFrom-Json
if ($LASTEXITCODE -eq 0 -and $params.Count -gt 0) {
    Write-Host "[!] Contrato SSM com $($params.Count) parametro(s) remanescente(s) da sessao anterior:" -ForegroundColor Yellow
    $params | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    Write-Host "    Valores antigos apontam para recursos que nao existem mais — o apply os sobrescreve." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "LEMBRETE: o painel de budget do lab atrasa 8-12h. Nao use como sinal de seguranca." -ForegroundColor Yellow
