# This file is "the recipe for building a box (image) that holds our app".
# An image built from this one recipe runs the same everywhere: your computer, the VPS, or Render.

# 1) Base: a small Linux with Python 3.12 installed
FROM python:3.12-slim

# Print Python logs right away instead of buffering them
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv

# 2) Install libraries first. They change less often than the code, so when only the code changes, this step is reused from cache.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3) Copy our code
COPY app ./app

# 4) Stamp the version (git commit) into the image at build time.
#    docker build --build-arg APP_VERSION=3f2a9c1 .
ARG APP_VERSION=
ENV APP_VERSION=$APP_VERSION

# 5) Security: run as a regular user, not the administrator (root)
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000

# 6) The command to run when the box is opened (the container starts).
#    Render sets the port through the PORT environment variable; without it, 8000 is used.
#    --forwarded-allow-ips="*": Caddy and Render handle HTTPS, then pass the request to us over plain http.
#    They add an X-Forwarded-Proto: https header to say so, and this flag tells uvicorn to believe it.
#    Without it, the login callback address would start with http:// and GitHub would reject it.
#    It's safe here because the app's port is never open to the internet, only to the proxy in front of it.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers --forwarded-allow-ips='*'"]
