import os
import json
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict
from langchain_core.messages import HumanMessage, AIMessage
from langchain_core.prompts import ChatPromptTemplate
from chains import llm, prompt 
from huggingface_hub import InferenceClient
import io

from langchain_community.tools import DuckDuckGoSearchRun
from agent import agent_brain

app = FastAPI()

hf_token = os.getenv("HUGGINGFACE_TOKEN")
mistral_api_key = os.getenv("MISTRAL_API_KEY")

# Debugging checks for Render logs
if not mistral_api_key:
    print("WARNING: MISTRAL_API_KEY environment variable is missing!")

if not hf_token:
    print("WARNING: HUGGINGFACE_TOKEN environment variable is missing!")

hf_client = InferenceClient(token=hf_token)


class GenRequest(BaseModel):
    prompt: str

@app.post("/analyze_image")
async def analyze_image(request: Request):
    try:
        content = await request.body()
        # Using Salesforce BLIP model via the hub client
        result = hf_client.image_to_text(content, model="Salesforce/blip-image-captioning-large")
        return {"generated_text": result}
    except Exception as e:
        print(f"Analyze Image Error: {e}")
        return Response(content=json.dumps({"error": str(e)}), status_code=500, media_type="application/json")

@app.post("/generate_image")
async def generate_image(req: GenRequest):
    try:
        # Using Stable Diffusion model via the hub client
        image = hf_client.text_to_image(req.prompt, model="runwayml/stable-diffusion-v1-5")
        
        img_byte_arr = io.BytesIO()
        image.save(img_byte_arr, format='PNG')
        return Response(content=img_byte_arr.getvalue(), media_type="image/png")
    except Exception as e:
        print(f"Generate Image Error: {e}")
        return Response(content=json.dumps({"error": str(e)}), status_code=500, media_type="application/json")

search_tool = DuckDuckGoSearchRun()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# endpoints
# ==========================================

class ChatRequest(BaseModel):
    message: str
    history: List[Dict[str, str]] = []

@app.post("/chat")
async def chat(req: ChatRequest):
    """BEST FOR POSTMAN: Returns a single JSON response."""
    try:
        response = agent_brain(req.message)
        return {"response": response}
    except Exception as e:
        print(f"Chat Error: {e}")
        return {"response": f"Error: {str(e)}"}

@app.post("/chat_stream")
async def chat_stream(req: ChatRequest):
    """BEST FOR MOBILE APP: Returns a streaming response."""
    async def generate():
        try:
            # Reconstruct chat history
            messages = []
            for msg in req.history:
                if msg.get("role") == "user":
                    messages.append(HumanMessage(content=msg.get("text", "")))
                else:
                    messages.append(AIMessage(content=msg.get("text", "")))

            input_data = {
                "message": req.message, 
                "chat_history": messages,
                "context": "General chat"
            }
            
            async for chunk in llm.astream(prompt.format_messages(**input_data)):
                content = chunk.content
                if content:
                    yield f"data: {json.dumps({'token': content})}\n\n"
            
            yield "data: [DONE]\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
            yield "data: [DONE]\n\n"
    
    return StreamingResponse(generate(), media_type="text-event-stream")

# ==========================================
# Start Server
# ==========================================
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)