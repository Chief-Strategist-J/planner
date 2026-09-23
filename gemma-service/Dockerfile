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

# Download Google Gemma 1.1 2B Instruct GGUF model file
RUN curl -L -o /app/models/gemma-2-2b-it-Q4_K_M.gguf "https://huggingface.co/google/gemma-1.1-2b-it-GGUF/resolve/main/2b_it_v1p1.gguf"

COPY app.py .

ENV PORT=8080
ENV MODEL_PATH=/app/models/gemma-2-2b-it-Q4_K_M.gguf
ENV NUM_THREADS=2

EXPOSE 8080

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
