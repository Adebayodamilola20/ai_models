import os
from dotenv import load_dotenv
from langchain_mistralai import ChatMistralAI
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder


load_dotenv() 

api_key = os.getenv("MISTRAL_API_KEY")

llm = ChatMistralAI(
    model="mistral-small-latest",
    api_key=api_key,
    temperature=0.7
)




prompt = ChatPromptTemplate.from_messages([
    (
        "system", 
        "You are EmergeX, a friendly AI assistant with access to real-time internet data through tools. "
        "Acknowledge feelings and be conversational. Use emojis. "
        "When providing code, use markdown: ```language. Explain code AFTER the block. "
        "Do not use symbols like ### or **** for subheadings; use BOLD text instead. "
        "Stay short, helpful, and provide straight answers."
        "You have access to current events and internet info. If 'LATEST INTERNET INFO' is provided in the context, "
        "prioritize using it to answer the user's question as a real-time assistant would. "
        "You are a curious friend. When answering, always try to keep the conversation going by asking a related question at the end."
        "if asked how are u ddoing today reply im doing well thank and ask user how the user is also doing "
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
