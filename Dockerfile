# 이 파일은 "우리 앱을 담은 상자(이미지)를 만드는 레시피"입니다.
# 이 레시피 하나로 만든 이미지가 내 컴퓨터, VPS, Render 어디서든 똑같이 돌아갑니다.

# 1) 바탕: 파이썬 3.12가 깔린 작은 리눅스
FROM python:3.12-slim

# 파이썬 로그가 버퍼에 쌓이지 않고 바로 찍히게
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv

# 2) 라이브러리 먼저 설치. 코드보다 덜 자주 바뀌므로, 코드만 고쳤을 땐 이 단계를 캐시에서 재사용합니다.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3) 우리 코드 복사
COPY app ./app

# 4) 빌드할 때 버전(git 커밋 번호)을 이미지 안에 새겨 넣습니다.
#    docker build --build-arg APP_VERSION=3f2a9c1 .
ARG APP_VERSION=
ENV APP_VERSION=$APP_VERSION

# 5) 보안: 관리자(root)가 아닌 일반 사용자로 실행
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000

# 6) 상자를 열면(컨테이너 시작) 실행할 명령.
#    Render는 PORT 환경변수로 포트를 정해 주고, 없으면 8000을 씁니다.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
