FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends docker.io wireguard-tools curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -f http://localhost:5000/health || exit 1

CMD ["python", "app.py"]
