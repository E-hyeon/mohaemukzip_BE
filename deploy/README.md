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
