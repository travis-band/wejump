# wejump 방명록: 배포를 배우는 데모 앱

중고등학생에게 **"코드를 배포한다"는 게 무엇인지** 가르치기 위한 레포입니다.
앱은 일부러 단순합니다 (이름 + 한마디를 남기는 방명록). 주인공은 앱이 아니라 **앱이 인터넷에 올라가는 과정**입니다.

- **앱**: Python(FastAPI) + HTML/CSS/바닐라 JS + PostgreSQL
- **트랙 1**: GCP 무료 서버 + Docker + Caddy + GitHub Actions, push하면 blue/green 무중단 배포 ($0)
- **트랙 2**: 같은 Dockerfile을 Render + Neon에 ($0)

화면 아래 배지는 지금 응답한 서버가 `blue`인지 `green`인지 보여 줍니다. 배포하는 동안 이 색이 새로고침 없이 바뀌는 게 수업의 하이라이트입니다.

## 30초 만에 실행

```bash
docker compose up --build
```

<http://localhost:8000>

## 수업 문서

| | 문서 | 내용 |
|---|---|---|
| 0 | [배포란 무엇인가](docs/00-배포란.md) | 큰 그림, 용어 |
| 1 | [내 컴퓨터에서](docs/01-로컬.md) | 로컬 실행, localhost의 한계 |
| 2 | [도커](docs/02-도커.md) | 이미지, 컨테이너, 볼륨 |
| 2-1 | [로컬 DB 접속](docs/02-1-로컬DB.md) | localhost로 DB 접속, DB 파일이 저장되는 곳 |
| 3 | [진짜 서버](docs/03-서버.md) | VPS, SSH, 도메인, HTTPS |
| 4 | [자동 배포](docs/04-자동화.md) | GitHub Actions, 시크릿 |
| 5 | [무중단 배포](docs/05-blue-green.md) | blue/green, 롤백, 로드밸런서 |
| 6 | [PaaS](docs/06-render.md) | Render + Neon |
| 참고 | [옵션 비교](docs/07-옵션비교.md) | 다른 방법들의 비용과 트레이드오프 |

## 레포 구조

```
app/                  앱 (main.py 백엔드, db.py SQL, static/ 프론트엔드, tests/)
Dockerfile            앱을 이미지로 만드는 레시피 (두 트랙 공통)
docker-compose.yml    내 컴퓨터용: 앱 + DB
deploy/vps/           트랙 1: 서버 생성·준비·배포·롤백 스크립트
.github/workflows/    트랙 1: push → 테스트 → 빌드 → 배포
render.yaml           트랙 2: Render 설정
docs/                 수업 문서
```

## 비밀은 어디에

| 비밀 | 사는 곳 | git에 있나 |
|---|---|---|
| 로컬 DB 비밀번호 | `docker-compose.yml`, `.env` (로컬 전용 값) | compose 파일만. 로컬 전용이라 괜찮음 |
| 서버 DB 비밀번호 | 서버의 `deploy/vps/.env` | 없음 |
| 서버 접속 키 | GitHub Secrets `VPS_SSH_KEY` | 없음 |
| Neon DB 주소 | Render 대시보드 | 없음 |
