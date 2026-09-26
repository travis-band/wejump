"""방명록 앱의 백엔드. 브라우저의 요청을 받아 DB를 읽고 쓰고, 화면 파일(static/)을 내려줍니다.

실행: uvicorn app.main:app --reload --env-file .env
"""

import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field

from app import db

# 지금 떠 있는 게 "어느 버전"의 "어느 색" 서버인지. 화면 아래에 표시됩니다.
#   APP_VERSION: 이미지를 빌드할 때 git 커밋 번호를 새겨 넣음 (Dockerfile 참고)
#   RENDER_GIT_COMMIT: Render가 자동으로 넣어주는 커밋 번호
#   APP_COLOR: blue / green (VPS), render (Render), local (내 컴퓨터)
VERSION = os.environ.get("APP_VERSION") or os.environ.get("RENDER_GIT_COMMIT", "")[:7] or "dev"
COLOR = os.environ.get("APP_COLOR", "local")


@asynccontextmanager
async def lifespan(app):
    db.init()  # 서버가 켜질 때 테이블 준비
    yield


app = FastAPI(title="wejump 방명록", lifespan=lifespan)


class NewMessage(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)  # 앞뒤 공백 제거 후 검사

    name: str = Field(min_length=1, max_length=30)
    body: str = Field(min_length=1, max_length=200)


@app.get("/api/messages")
def list_messages():
    return db.list_messages()


@app.post("/api/messages", status_code=201)
def create_message(msg: NewMessage):
    return db.add_message(msg.name, msg.body)


@app.get("/api/version")
def version():
    return {"version": VERSION, "color": COLOR}


@app.get("/healthz")
def healthz():
    """헬스체크: '나 건강해요'를 확인하는 주소.
    배포 스크립트와 Render가 새 서버를 트래픽에 투입하기 전에 이 주소를 두드려 봅니다.
    DB에 연결이 안 되면 503을 돌려줘서 '아직 손님 받으면 안 됨'을 알립니다.
    """
    try:
        db.ping()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"db unavailable: {type(e).__name__}")
    return {"ok": True, "version": VERSION, "color": COLOR}


# 위에서 처리하지 않은 나머지 주소(/, /app.js, /style.css ...)는 static 폴더의 파일로 응답
app.mount("/", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="static")
