# 05. 무중단 배포 (blue/green)와 로드밸런서

**목표**: 사이트를 한 번도 끊지 않고 새 버전으로 갈아 끼우는 원리를 이해하고, 되돌리기(롤백)와 로드밸런싱을 직접 해 본다.

## 그냥 껐다 켜면 안 되나?

가장 단순한 배포는 "옛 앱 끄기 → 새 앱 켜기"입니다. 그 사이 몇 초~수십 초 동안 손님은 에러를 봅니다. 새 버전이 고장났다면 사이트는 계속 죽어 있습니다.

## 아이디어: 칸 두 개와 스위치 하나

```
                     ┌─▶ app-blue   (v1, 손님 받는 중)
손님 ──▶ Caddy(스위치) ┤
                     └ ─ app-green  (비어 있음)
```

1. 손님이 없는 칸(green)에 새 버전(v2)을 띄운다
2. green이 건강한지 `/healthz`로 확인한다
3. 건강하면 스위치를 green 쪽으로 돌린다 ← **이 순간이 배포**
4. blue는 끄되 지우지 않는다 → 문제가 생기면 스위치만 되돌리면 됨

새 버전이 아프면 3번을 하지 않으므로, 손님은 아무 일 없었던 것처럼 v1을 계속 씁니다.

[`deploy/vps/deploy.sh`](../deploy/vps/deploy.sh)를 열어 보면 주석으로 0~4단계가 나뉘어 있습니다. 스위치의 실체는 Caddyfile 한 줄입니다.

```
wejump.duckdns.org {
	reverse_proxy app-green:8000      ← 이 단어 하나를 blue ↔ green 으로 바꾸고
}                                       caddy reload (연결을 끊지 않고 설정만 교체)
```

## 교실 시연

1. 학생들이 폰으로 사이트를 열어 둡니다. 화면 아래 배지가 파란색 `blue`.
2. 선생님이 코드를 고쳐 push합니다.
3. 2~3분 뒤, 학생들 폰의 배지가 **새로고침 없이** 초록색 `green`과 새 버전 번호로 바뀝니다.
4. 그동안 글쓰기는 한 번도 실패하지 않습니다.

## 측정: 정말 한 번도 안 끊겼나

배포하는 동안 다른 터미널에서 이걸 돌려 두세요. 0.2초마다 사이트를 두드리고 결과를 찍습니다.

```bash
while true; do
  curl -s -o /dev/null -w "%{http_code} " https://wejump.duckdns.org/healthz
  curl -s https://wejump.duckdns.org/api/version; echo
  sleep 0.2
done
```

`200 {"color":"blue"...}` 가 이어지다가 어느 순간 `200 {"color":"green"...}` 으로 바뀌고, 그 사이에 200이 아닌 줄이 없어야 합니다.

이 레포를 만들 때 내 컴퓨터에서 같은 실험을 한 결과:

| 항목 | 결과 |
|---|---|
| 전환 중 보낸 요청 | 125개 |
| 실패한 요청 | 0개 |
| 롤백에 걸린 시간 | 약 5초 |

## 롤백: 되돌리기

```bash
./rollback.sh
```

[`rollback.sh`](../deploy/vps/rollback.sh)는 딱 한 가지 일만 합니다. 꺼져 있는 반대쪽 칸의 버전 번호를 읽어서 `deploy.sh`에 넘깁니다. **롤백은 특별한 기능이 아니라 "직전 버전을 다시 배포"하는 것**입니다. 이미지가 서버에 이미 있으니 몇 초면 끝납니다.

## 안전망은 두 겹

| 안전망 | 어디서 | 무엇을 막나 |
|---|---|---|
| 테스트 | GitHub Actions `test` | 기능이 틀린 코드 ([04](04-자동화.md)의 실험) |
| 헬스체크 | `deploy.sh` 2단계 | 테스트는 통과했지만 서버에서 켜지지 않는 버전 (설정 누락, DB 연결 실패 등) |

## 내 컴퓨터에서 연습하기

서버 없이도 똑같이 해 볼 수 있습니다. 레지스트리 대신 내 컴퓨터에 이미지를 만들어 둡니다.

```bash
cd deploy/vps
cp .env.example .env
```

`.env`를 이렇게 고칩니다. `DOMAIN=:80`은 "도메인 없이 80번 포트에서 HTTP로 받기"라는 뜻입니다.

```
DOMAIN=:80
IMAGE=wejump-local
POSTGRES_PASSWORD=practice123
BLUE_TAG=
GREEN_TAG=
HTTP_PORT=8080
HTTPS_PORT=8443
```

```bash
# 버전 두 개 만들기
docker build -t wejump-local:v1 --build-arg APP_VERSION=v1 ../..
docker build -t wejump-local:v2 --build-arg APP_VERSION=v2 ../..

./deploy.sh v1        # http://localhost:8080 → blue, v1
./deploy.sh v2        # → green, v2 (측정 루프를 localhost:8080 으로 돌려 보세요)
./rollback.sh         # → blue, v1

# 일부러 고장난 버전: 켜지자마자 죽는 이미지
printf 'FROM wejump-local:v2\nCMD ["python","-c","raise SystemExit(1)"]\n' \
  | docker build -t wejump-local:broken -
./deploy.sh broken    # ✗ 건강하지 않음 → 사이트는 그대로 blue

# 정리
docker compose -f docker-compose.prod.yml down -v
```

## 실험: 로드밸런서 만들기

지금 Caddy는 한 번에 한 칸만 가리키는 **스위치**입니다. 두 칸을 동시에 가리키면 **로드밸런서**가 됩니다.

서버(또는 위의 연습 환경)에서:

```bash
dc start app-blue app-green      # 두 칸 모두 켜기 (dc 별명은 03 참고)
```

`Caddyfile`을 이렇게 고치고 `dc exec caddy caddy reload --config /etc/caddy/Caddyfile`:

```
wejump.duckdns.org {
	reverse_proxy app-blue:8000 app-green:8000 {
		lb_policy round_robin
	}
}
```

이제 사이트를 열어 두면 배지가 2초마다 blue, green, blue, green… 으로 번갈아 바뀝니다. 요청 하나하나가 두 서버에 나눠 가는 것이 눈에 보입니다.

- `lb_policy round_robin`: 순서대로 번갈아. 이걸 빼면 Caddy 기본값인 **무작위**가 됩니다 (blue가 연달아 나오기도 함).
- 진짜 서비스의 로드밸런서는 여러 **서버**에 나눠 보내고, 헬스체크에 실패한 서버를 자동으로 빼 줍니다. 여기서는 한 서버 안의 컨테이너 두 개라서, 서버가 통째로 죽으면 둘 다 죽습니다.
- 실험이 끝나면 `./deploy.sh <지금 태그>`를 한 번 실행해서 Caddyfile을 원래대로 돌려 놓으세요.

## 한계와 더 생각해 볼 것

- **DB는 하나를 같이 씁니다.** blue와 green이 같은 DB를 보므로, 새 버전이 테이블 구조를 바꾸면 옛 버전이 깨질 수 있습니다. 실제 서비스에서는 "옛 버전도 이해할 수 있게 조금씩 바꾸기"를 합니다.
- **서버가 한 대입니다.** 서버가 꺼지면 사이트도 꺼집니다. 서버 여러 대 + 앞단 로드밸런서가 다음 단계입니다. GCP의 관리형 로드밸런서는 월 18달러 정도라 이 수업에서는 쓰지 않았습니다.
- 이 모든 걸 누가 대신 해 주면? → [06-render](06-render.md)
