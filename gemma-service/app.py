import os
import time
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gemma-service")

app = FastAPI(title="Google Gemma 2B LLM Service", version="1.0.0")

MODEL_PATH = os.getenv("MODEL_PATH", "/app/models/gemma-2-2b-it-Q4_K_M.gguf")

llm = None

def get_llm():
	global llm
	if llm is None:
		if os.path.exists(MODEL_PATH):
			size_bytes = os.path.getsize(MODEL_PATH)
			logger.info(f"Model path found! Size: {size_bytes} bytes. Attempting Llama load...")
			
			# Attempt loading with different llama parameter fallback combinations
			from llama_cpp import Llama
			try:
				logger.info("Attempt 1: Loading with standard n_ctx=2048...")
				llm = Llama(
					model_path=MODEL_PATH,
					n_ctx=2048,
					n_threads=int(os.getenv("NUM_THREADS", "2")),
					verbose=True
				)
			except Exception as e1:
				logger.warning(f"Attempt 1 failed: {e1}. Trying Attempt 2 with n_ctx=512 and chat_format='gemma'...")
				try:
					llm = Llama(
						model_path=MODEL_PATH,
						n_ctx=512,
						n_threads=1,
						chat_format="gemma",
						verbose=True
					)
				except Exception as e2:
					logger.error(f"Attempt 2 failed: {e2}. Trying Attempt 3 minimal params...")
					llm = Llama(
						model_path=MODEL_PATH,
						verbose=True
					)
			logger.info("Gemma model loaded successfully!")
		else:
			logger.error(f"Model file not found at {MODEL_PATH}")
			raise HTTPException(status_code=500, detail=f"Model file missing at {MODEL_PATH}")
	return llm

@app.get("/health")
def health():
	model_exists = os.path.exists(MODEL_PATH)
	return {
		"status": "healthy",
		"service": "gemma-2b-llm-service",
		"model_file_exists": model_exists,
		"model_loaded": llm is not None,
		"model_name": "gemma-2-2b-it-Q4_K_M"
	}

@app.get("/v1/models")
def list_models():
	return {
		"object": "list",
		"data": [
			{
				"id": "gemma-2-2b-it",
				"object": "model",
				"owned_by": "google",
				"permission": []
			}
		]
	}

class ChatMessage(BaseModel):
	role: str
	content: str

class ChatCompletionRequest(BaseModel):
	messages: List[ChatMessage]
	temperature: Optional[float] = 0.7
	max_tokens: Optional[int] = 256

@app.post("/v1/chat/completions")
def chat_completions(req: ChatCompletionRequest):
	try:
		model_obj = get_llm()
		if model_obj is None:
			raise HTTPException(status_code=503, detail="Gemma model failed to load or file missing.")

		prompt = ""
		for msg in req.messages:
			if msg.role == "system":
				prompt += f"<start_of_turn>user\nSystem: {msg.content}<end_of_turn>\n"
			elif msg.role == "user":
				prompt += f"<start_of_turn>user\n{msg.content}<end_of_turn>\n"
			elif msg.role == "assistant":
				prompt += f"<start_of_turn>model\n{msg.content}<end_of_turn>\n"
		prompt += "<start_of_turn>model\n"

		max_t = req.max_tokens if req.max_tokens else 256
		temp = req.temperature if req.temperature is not None else 0.7

		output = model_obj(
			prompt,
			max_tokens=max_t,
			temperature=temp,
			stop=["<end_of_turn>", "<eos>"]
		)
	except HTTPException:
		raise
	except Exception as e:
		logger.error(f"Inference error: {e}", exc_info=True)
		raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")

	text_response = output["choices"][0]["text"].strip()
	usage = output.get("usage", {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0})

	return {
		"id": f"chatcmpl-gemma-{int(time.time())}",
		"object": "chat.completion",
		"created": int(time.time()),
		"model": "gemma-2-2b-it",
		"choices": [
			{
				"index": 0,
				"message": {
					"role": "assistant",
					"content": text_response
				},
				"finish_reason": "stop"
			}
		],
		"usage": usage
	}
