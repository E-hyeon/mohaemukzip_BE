# kind 클러스터 생성 -> 이미지 빌드/로드 -> MySQL, Redis, 앱 Helm 설치
# 사용: powershell -File deploy/deploy.ps1 [-SkipBuild]
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'

$root = Resolve-Path "$PSScriptRoot\.."
$cluster = 'mohaemukzip'
$image = 'mohaemukzip-api:local'
$secretFile = Join-Path $PSScriptRoot 'values-secret.yaml'

function Run($cmd) {
    & $cmd[0] $cmd[1..($cmd.Length - 1)]
    if ($LASTEXITCODE -ne 0) { throw "실패: $($cmd -join ' ')" }
}

if (-not (kind get clusters | Select-String -SimpleMatch $cluster)) {
    Run @('kind', 'create', 'cluster', '--config', "$PSScriptRoot\kind\kind-config.yaml")
}
kubectl config use-context "kind-$cluster" | Out-Null

if (-not $SkipBuild) {
    Push-Location $root
    Run @("$root\gradlew.bat", 'clean', 'bootJar', '-x', 'test')
    Run @('docker', 'build', '-t', $image, '.')
    Pop-Location
}
Run @('kind', 'load', 'docker-image', $image, '--name', $cluster)

$extra = @()
if (Test-Path $secretFile) { $extra = @('-f', $secretFile) }

# 앱 차트의 ServiceMonitor CRD 가 필요하므로 kube-prometheus-stack 을 먼저 설치
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update | Out-Null
Run @('helm', 'upgrade', '--install', 'kube-prometheus-stack', 'prometheus-community/kube-prometheus-stack',
      '--namespace', 'monitoring', '--create-namespace',
      '-f', "$PSScriptRoot\monitoring\kube-prometheus-stack-values.yaml", '--wait', '--timeout', '10m')

# 같은 secret 파일을 양쪽에 넘김 (mysql 은 auth.*, 앱은 db.* / secrets.* 를 읽음)
Run (@('helm', 'upgrade', '--install', 'mysql', "$PSScriptRoot\charts\mysql", '--wait', '--timeout', '5m') + $extra)
Run @('helm', 'upgrade', '--install', 'redis', "$PSScriptRoot\charts\redis", '--wait', '--timeout', '3m')
Run (@('helm', 'upgrade', '--install', 'mohaemukzip', "$PSScriptRoot\charts\mohaemukzip", '--wait', '--timeout', '5m') + $extra)

Write-Host "`n배포 완료: http://localhost:8080/swagger-ui  (health: kubectl get pods)"
Write-Host "Grafana: http://localhost:3000 (admin/admin) -> Dashboards -> mohaemukzip API RED"
