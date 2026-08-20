<#
.SYNOPSIS
    Propaga as credenciais temporárias do Learner Lab para os GitHub Secrets dos 4 repositórios.

.DESCRIPTION
    A sessão do lab dura ~4h e as credenciais mudam a cada início; sem isto toda pipeline falha em
    `configure-aws-credentials`. Requer `gh auth login` e o bloco "AWS Details" já em ~/.aws/credentials.

    Na PRIMEIRA execução passe também -ClusterRoleName, -NodeRoleName e -StateBucket: as variables
    não mudam entre sessões, mas sem elas o workflow de Terraform falha de propósito.

.EXAMPLE
    .\scripts\refresh-gh-secrets.ps1 -Org meu-usuario-github
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Org,
    [string]$Profile = "default",
    [string]$ClusterRoleName,
    [string]$NodeRoleName,
    [string]$StateBucket,
    [string[]]$Repos = @(
        "fiap-fase3-infra-k8s",
        "fiap-fase3-infra-db",
        "fiap-fase3-app",
        "fiap-fase3-auth-serverless"
    )
)

$ErrorActionPreference = "Stop"

$null = gh auth status
if ($LASTEXITCODE -ne 0) { throw "gh nao autenticado. Rode: gh auth login" }

$keyId = aws configure get aws_access_key_id --profile $Profile
$secret = aws configure get aws_secret_access_key --profile $Profile
$token = aws configure get aws_session_token --profile $Profile

if (-not $keyId -or -not $secret -or -not $token) {
    throw "Credenciais incompletas no perfil '$Profile'. O Learner Lab exige os TRES valores (a sessao e temporaria, precisa do session token)."
}

# Confirma que a credencial esta viva ANTES de espalhar por 4 repos.
$identity = aws sts get-caller-identity --profile $Profile --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "As credenciais do perfil '$Profile' nao sao validas (sessao expirada?)." }
Write-Host "Credencial valida — conta $($identity.Account)" -ForegroundColor Green

foreach ($repo in $Repos) {
    $target = "$Org/$repo"
    Write-Host "-> $target" -ForegroundColor Cyan
    gh secret set AWS_ACCESS_KEY_ID     -R $target -b $keyId
    gh secret set AWS_SECRET_ACCESS_KEY -R $target -b $secret
    gh secret set AWS_SESSION_TOKEN     -R $target -b $token
    if ($LASTEXITCODE -ne 0) { Write-Warning "Falha em $target (o repo ja existe no GitHub?)" }

    if ($ClusterRoleName) { gh variable set CLUSTER_ROLE_NAME -R $target -b $ClusterRoleName }
    if ($NodeRoleName) { gh variable set NODE_ROLE_NAME    -R $target -b $NodeRoleName }
    if ($StateBucket) { gh variable set TF_STATE_BUCKET   -R $target -b $StateBucket }
}

Write-Host ""
Write-Host "Secrets atualizados. Valem enquanto a sessao do lab estiver ativa (~4h)." -ForegroundColor Green
if (-not $NodeRoleName) {
    Write-Host "Dica: na primeira execucao passe -ClusterRoleName e -NodeRoleName (do preflight) e" -ForegroundColor Yellow
    Write-Host "      -StateBucket (do bootstrap), senao o workflow de Terraform falha." -ForegroundColor Yellow
}
