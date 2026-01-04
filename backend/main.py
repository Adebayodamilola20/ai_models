import os
import json
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict
from langchain_core.messages import HumanMessage, AIMessage
from langchain_core.prompts import ChatPromptTemplate
from chains import llm, prompt 

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str
    history: List[Dict[str, str]] = []


class TitleRequest(BaseModel):
    message: str


title_prompt = ChatPromptTemplate.from_template(
    "You are a helpful assistant that creates short, catchy 3-word titles for chat history. "
    "Based on this user message, provide ONLY the title without quotes or periods: {first_message}"
)

@app.post("/generate_title")
async def generate_title(req: TitleRequest):
    try:
       
        response = await llm.ainvoke(title_prompt.format_messages(first_message=req.message))
        
       
        clean_title = response.content.replace('"', '').replace('.', '').strip()
        
       
        words = clean_title.split()
        if len(words) > 4:
            clean_title = " ".join(words[:3])
            
        return {"title": clean_title}
    except Exception as e:
        print(f"Error generating title: {e}")
        return {"title": "New Conversation"}

@app.post("/chat_stream")
async def chat_stream(req: ChatRequest):
    async def generate():
        messages = []
        
        # Build the conversation context
        for msg in req.history:
            if msg.get("role") == "user":
                messages.append(HumanMessage(content=msg.get("text", "")))
            else:
                messages.append(AIMessage(content=msg.get("text", "")))
        
        messages.append(HumanMessage(content=req.message))

        # Prepare input for the chain
        input_data = {"message": req.message, "chat_history": messages[:-1]}
        
        # Stream the response tokens
        async for chunk in llm.astream(prompt.format_messages(**input_data)):
            content = chunk.content
            if content:
                yield f"data: {json.dumps({'token': content})}\n\n"
        
        yield "data: [DONE]\n\n"
    
    return StreamingResponse(generate(), media_type="text-event-stream")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=4040)