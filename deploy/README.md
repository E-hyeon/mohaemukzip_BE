# kind + Helm 배포

MySQL, Redis, 앱을 Helm 차트로 나눠서 kind 클러스터에 올린다.

## 실행

Docker Desktop, kind, helm, kubectl이 필요하다.

```powershell
cp deploy/values-secret.example.yaml deploy/values-secret.yaml   # 키 채우기 (JWT_SECRET은 base64)
powershell -File deploy/deploy.ps1                               # 이미지 재빌드 생략: -SkipBuild
```

접속은 http://localhost:8080/swagger-ui

정리는 `kind delete cluster --name mohaemukzip`

## 메모

- `application-prod.yaml`에서 Redis host가 `redis`로 고정돼 있어서 릴리스명을 `redis`, `mysql`, `mohaemukzip`으로 맞췄다.
- Docker Desktop이 cgroup v1이라 최신 kind 노드 이미지가 안 떠서 `kindest/node:v1.32.8`로 고정했다.
- health 체크에서 mail은 뺐다. 메일 계정이 없으면 Gmail 로그인 실패로 readiness가 DOWN이 된다.

## 모니터링 (kube-prometheus-stack, RED 대시보드)

`deploy.ps1`이 `monitoring` 네임스페이스에 kube-prometheus-stack을 먼저 설치한다 (`monitoring/kube-prometheus-stack-values.yaml`).

- 수집: 앱 차트의 `ServiceMonitor`가 Service의 `management` 포트(9091)에서 `/actuator/prometheus`를 15초마다 스크레이프한다. 앱은 `micrometer-registry-prometheus`로 메트릭을 내고, `http.server.requests` 히스토그램 버킷은 `application.yaml`에서 켰다.
- 대시보드: `charts/mohaemukzip/dashboards/red.json`이 `grafana_dashboard: "1"` 라벨의 ConfigMap으로 배포되고 Grafana sidecar가 자동으로 불러온다. API(uri)별 Rate / Errors(5xx) / Duration(p50·p95·p99)을 보여준다.
- 접속: http://localhost:3000 (admin / admin) → Dashboards → `mohaemukzip API RED`. 포트(3000)는 `kind-config.yaml`에 추가했으므로 **기존 클러스터는 지우고 다시 만들어야 한다** (`kind delete cluster --name mohaemukzip`). 다시 만들기 싫으면 `kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80`.
- Prometheus UI: `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090`
- 모니터링 없이 앱만 올릴 때는 `--set serviceMonitor.enabled=false --set grafanaDashboard.enabled=false`.
