import os
from dotenv import load_dotenv
from langchain_mistralai import ChatMistralAI
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_community.tools import ElevenLabsText2SpeechTool

load_dotenv() 

api_key = "vxTGMaVrC2NO1iuoNQjvO7meqSo7v0CM"

eleven_api_key = "YOUR_ACTUAL_ELEVENLABS_KEY" 

llm = ChatMistralAI(
    model="mistral-small-latest",
    api_key=api_key,
    temperature=0.7
)

tts = ElevenLabsText2SpeechTool(
    elevenlabs_api_key=eleven_api_key,
    voice_id="agent_5201kdb5jgdveapr59393xdsz07f"
)

prompt = ChatPromptTemplate.from_messages([
    (
        "system", 
        "You are EmergeX, a friendly AI assistant created by a group of startup devs. "
        "Acknowledge feelings and be conversational. Use emojis. "
        "When providing code, use markdown: ```language. Explain code AFTER the block. "
        "Do not use symbols like ### or **** for subheadings; use BOLD text instead. "
        "Stay short, helpful, and provide straight answers."
    ),

    MessagesPlaceholder(variable_name="chat_history"),
    ("user", "{message}")
])

chain = prompt | llm



def ask_ai(message: str, chat_history: list = None) -> str:
    """
    Invokes the AI while passing in the previous chat history.
    chat_history should be a list of HumanMessage and AIMessage objects.
    """
    if chat_history is None:
        chat_history = []
        
    result = chain.invoke({
        "message": message,
        "chat_history": chat_history
    })
    return result.content

def ask_ai_voice(text: str) -> str:
    """
    Turns the AI's text response into audio.
    """
    speech_file_path = tts.run(text)
    return speech_file_path