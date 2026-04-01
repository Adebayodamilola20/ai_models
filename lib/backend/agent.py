import json
from langchain_core.prompts import ChatPromptTemplate
from typing import Dict, Any

# Adjust imports based on your actual project structure
from .chains import llm, ask_ai

# Replace this with the actual import for your rag_chain
try:
    from .chains import rag_chain
except ImportError:
    # Fallback if rag_chain is defined elsewhere or not yet implemented
    rag_chain = None


# 1. Intent Detection Setup
INTENT_SYSTEM_PROMPT = """
You are an intent detection classifier. 
Analyze the user input and classify it into EXACTLY ONE of the following categories:
- 'document_search': The user is asking about documents, manuals, specific files, or needs to search a knowledge base.
- 'coding': The user is asking about programming, writing code, debugging, or technical implementation.
- 'general_chat': All other conversational queries, greetings, or general non-technical questions.

Respond ONLY with a JSON object in this format:
{"intent": "category"}
"""

intent_prompt = ChatPromptTemplate.from_messages([
    ("system", INTENT_SYSTEM_PROMPT),
    ("user", "{user_input}")
])

intent_chain = intent_prompt | llm


# 2. Coding Assistant Setup
CODING_SYSTEM_PROMPT = """
You are an expert software engineer and pair programmer. 
Provide clean, efficient, and well-documented code. 
Only output exactly what is asked. Explain your code briefly if necessary.
"""

coding_prompt = ChatPromptTemplate.from_messages([
    ("system", CODING_SYSTEM_PROMPT),
    ("user", "{user_input}")
])

coding_chain = coding_prompt | llm


def detect_intent(user_input: str) -> str:
    """Classifies the user's input into a predefined intent."""
    try:
        response = intent_chain.invoke({"user_input": user_input})
        
        # Clean response and parse JSON
        content = response.content.strip()
        if content.startswith("```json"):
            content = content.replace("```json", "").replace("```", "").strip()
            
        parsed = json.loads(content)
        return parsed.get("intent", "general_chat")
    except Exception as e:
        print(f"Intent detection failed: {e}")
        return "general_chat"


def agent_brain(user_input: str) -> Dict[str, Any]:
    """
    Main entry point for the AI Agent.
    Routes the user input to the specific tool/chain based on intent.
    """
    # Detect Intent
    intent = detect_intent(user_input)
    
    response_content = ""
    
    # Route based on detected intent
    if intent == "document_search":
        if rag_chain is not None:
            # Use existing rag_chain (adjust key/returns mapping based on your implementation)
            result = rag_chain.invoke({"query": user_input})
            # Assuming it returns a dict with 'result' or 'answer', otherwise cast to str
            response_content = result if isinstance(result, str) else result.get("answer", str(result))
        else:
            response_content = "Document search is currently unavailable. Please configure rag_chain."
            
    elif intent == "coding":
        # Use LLM with coding prompt
        result = coding_chain.invoke({"user_input": user_input})
        response_content = result.content
        
    else:  
        # normal chat response (general_chat)
        response_content = ask_ai(user_input)
        
    return {
        "intent": intent,
        "response": response_content
    }


# ==========================================
# HOW TO USE IN main.py (or your API router)
# ==========================================
"""
# main.py

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Import the new agent_brain
from lib.backend.agent import agent_brain

app = FastAPI()

class ChatRequest(BaseModel):
    message: str

@app.post("/api/chat")
async def chat_endpoint(request: ChatRequest):
    try:
        # Pass the input to our new AI agent
        result = agent_brain(request.message)
        
        return {
            "status": "success",
            "intent_detected": result["intent"], # e.g. "coding"
            "reply": result["response"]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
"""
