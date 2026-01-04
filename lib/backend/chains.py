import os
from dotenv import load_dotenv
from langchain_mistralai import ChatMistralAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_community.tools import ElevenLabsText2SpeechTool

load_dotenv() 

api_key = "vxTGMaVrC2NO1iuoNQjvO7meqSo7v0CM"
eleven_api_key = os.getenv("ELEVENLABS_API_KEY")

llm = ChatMistralAI(
    model="mistral-small-latest",
    api_key=api_key,
    temperature=0.7
)

# Add TTS back
tts = ElevenLabsText2SpeechTool(
    eleven_api_key=eleven_api_key,
    voice_id="YOUR_ELEVENLABS_VOICE_ID"  # NOT agent ID, use actual voice ID
)

prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a friendly AI assistant..."),
    ("user", "{message}")
])

chain = prompt | llm

def ask_ai(message: str) -> str:
    result = chain.invoke({"message": message})
    return result.content

def ask_ai_voice(text: str) -> str:
    speech_file_path = tts.run(text)
    return speech_file_path