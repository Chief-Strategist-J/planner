FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /app/models

# Download Google Gemma 2 2B Instruct GGUF model file (public un-gated repository)
RUN curl -L -o /app/models/gemma-2-2b-it-Q4_K_M.gguf "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"

COPY app.py .

ENV PORT=8080
ENV MODEL_PATH=/app/models/gemma-2-2b-it-Q4_K_M.gguf
ENV NUM_THREADS=2

EXPOSE 8080

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
