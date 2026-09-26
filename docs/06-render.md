# 06. PaaS로 15분 만에: Render + Neon

**목표**: 트랙 1에서 직접 만든 것들을 플랫폼(PaaS)이 대신해 주면 어떻게 되는지 경험하고, 편리함과 맞바꾼 것이 무엇인지 비교한다.

## PaaS란

**P**latform **a**s **a** **S**ervice. "서버는 우리가 관리할게, 너는 코드만 줘"라는 서비스입니다. Render, Railway, Heroku, Fly.io 등이 있습니다.

같은 `Dockerfile`을 그대로 씁니다. 바뀌는 것은 **누가 인프라를 관리하느냐**뿐입니다.

## 누가 무엇을 하나

| 할 일 | 트랙 1 (VPS) | 트랙 2 (Render) |
|---|---|---|
| 서버 빌리기 | 우리 (`create-vm.sh`) | Render |
| Docker 설치, 스왑, 사용자 | 우리 (`setup.sh`) | Render |
| 이미지 빌드 | GitHub Actions | Render |
| 이미지 창고 | ghcr.io | Render 내부 |
| 도메인 | DuckDNS | `*.onrender.com` 자동 |
| HTTPS 인증서 | Caddy | Render |
| 헬스체크 후 교체 (무중단) | `deploy.sh` | Render |
| 롤백 | `rollback.sh` | 대시보드의 Rollback 버튼 |
| DB | 서버 안 Postgres 컨테이너 | Neon (다른 회사) |
| 비밀 보관 | 서버 `.env` + GitHub Secrets | Render 대시보드 Environment |
| 설정 파일 | `deploy/vps/` 폴더 전체 | [`render.yaml`](../render.yaml) 한 파일 |

## 왜 DB는 Neon인가

Render에도 무료 Postgres가 있지만 **만든 지 30일이 지나면 삭제**됩니다. Neon 무료 플랜은 기한이 없습니다 (저장 0.5GB, 안 쓰면 자동으로 잠들었다가 요청이 오면 깨어남).

## 1. Neon에서 DB 만들기

1. <https://neon.com> 에 GitHub 계정으로 가입 (카드 불필요).
2. **New Project** → 이름 `wejump`, 리전은 **AWS Asia Pacific (Singapore)**.
3. 대시보드의 **Connect** 버튼 → 연결 문자열을 복사합니다.
   ```
   postgresql://neondb_owner:비밀번호@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
   ```
   이 문자열 안에 비밀번호가 들어 있습니다. **이게 시크릿**입니다. 채팅방이나 코드에 붙여 넣지 마세요.

## 2. Render에 배포

1. <https://render.com> 에 GitHub 계정으로 가입 (무료 플랜은 카드 불필요).
2. **New** → **Blueprint** → `wejump` 레포 선택.
3. Render가 `render.yaml`을 읽고 무엇을 만들지 보여 줍니다. `DATABASE_URL` 입력 칸에 Neon 연결 문자열을 붙여 넣고 **Deploy Blueprint**.
4. 몇 분 뒤 `https://wejump-xxxx.onrender.com` 주소가 생깁니다.

화면 아래 배지가 보라색 `render`, 버전은 커밋 번호 7자리입니다.

## 3. 자동 배포

`render.yaml`의 `autoDeployTrigger: checksPass` 덕분에, push하면 **GitHub Actions 검사가 모두 통과한 뒤에** Render가 배포합니다. 트랙 1과 같은 테스트 관문을 공유하는 셈입니다.

> ⚠️ "모든 검사"에는 트랙 1의 `deploy` 단계도 들어갑니다. VPS 서버를 꺼 두면 그 단계가 실패해서 Render도 배포를 멈춥니다. VPS를 쓰지 않을 때는 GitHub Variables에서 `VPS_HOST`를 지우세요. 그러면 `deploy` 단계는 건너뛰고(통과로 취급) Render만 배포됩니다.

## 무료 플랜의 특징

- **15분 동안 아무도 안 들어오면 잠듭니다.** 다음 방문자는 깨어나는 동안 1분 정도 기다립니다. 수업 시작 5분 전에 한 번 열어 두세요.
- 무중단 배포, HTTPS, 로그 화면은 무료에서도 됩니다.

## 비교해 보기

| | 트랙 1 (VPS) | 트랙 2 (Render) |
|---|---|---|
| 처음 설정 시간 | 1~2시간 | 15분 |
| 월 비용 | $0 | $0 |
| 카드 등록 | 필요 (GCP) | 불필요 |
| 잠듦 | 없음 | 15분 무활동 시 |
| 안이 보이나 | 전부 (파일, 로그, 컨테이너, DB) | 대시보드가 보여주는 만큼만 |
| 다른 곳으로 옮기기 | 리눅스 서버면 어디든 같은 파일로 | `render.yaml`은 Render 전용. `Dockerfile`은 어디서든 |

## 생각해 볼 것

- 트랙 1을 먼저 했기 때문에 Render 화면의 "Deploy live", "Health check passed" 같은 말이 무슨 뜻인지 압니다. 순서를 바꿔서 Render부터 했다면 어땠을까요?
- 앱이 커지면 어느 쪽이 편할까요? 한 달에 사용자가 1만 명이라면? 100만 명이라면?
- 다른 선택지와 비용 → [07-옵션비교](07-옵션비교.md)
