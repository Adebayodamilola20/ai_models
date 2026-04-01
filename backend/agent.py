from typing import Dict, Any, TypedDict, Annotated
import operator
import json
from langgraph.graph import StateGraph, START, END
from langchain_core.prompts import ChatPromptTemplate
from langsmith import traceable

# Local imports
from chains import llm, ask_ai
try:
    from chains import rag_chain
except ImportError:
    rag_chain = None

# ==========================================
# 1. State Definition
# ==========================================
class AgentState(TypedDict):
    messages: Annotated[list, operator.add]
    user_input: str
    intent: str
    response: str

# ==========================================
# 2. Prompts
# ==========================================
INTENT_PROMPT = ChatPromptTemplate.from_messages([
    ("system", "You are an intent classifier. Categorize into ONE of: 'document_search', 'coding', 'general_chat'. Respond only with JSON: {{\"intent\": \"category\"}}"),
    ("user", "{user_input}")
])

CODING_PROMPT = ChatPromptTemplate.from_messages([
    ("system", "You are an expert coder. Provide clean, well-documented code."),
    ("user", "{user_input}")
])

# ==========================================
# 3. Graph Nodes (REAL Logic restored)
# ==========================================
def detect_intent_node(state: AgentState) -> Dict:
    """Node: Detects the intent of the user message."""
    user_input = state["user_input"]
    try:
        chain = INTENT_PROMPT | llm
        result = chain.invoke({"user_input": user_input})
        content = result.content.strip().replace("```json", "").replace("```", "").strip()
        parsed = json.loads(content)
        intent = parsed.get("intent", "general_chat")
    except Exception:
        intent = "general_chat"
        
    return {"intent": intent}

def rag_node(state: AgentState) -> Dict:
    """Node: Handles document search queries."""
    if rag_chain is not None:
        result = rag_chain.invoke({"query": state["user_input"]})
        ans = result if isinstance(result, str) else result.get("answer", str(result))
    else:
        ans = "Document search is currently unavailable."
    return {"response": ans}

def coding_node(state: AgentState) -> Dict:
    """Node: Handles coding-related queries."""
    chain = CODING_PROMPT | llm
    result = chain.invoke({"user_input": state["user_input"]})
    return {"response": result.content}

def general_chat_node(state: AgentState) -> Dict:
    """Node: Handles general conversational queries."""
    ans = ask_ai(state["user_input"])
    return {"response": ans}

# ==========================================
# 4. Routing Logic
# ==========================================
def route_intent(state: AgentState) -> str:
    """Conditional Edge: Routes based on intent."""
    return state.get("intent", "general_chat")

# ==========================================
# 5. Build and Compile Graph
# ==========================================
workflow = StateGraph(AgentState)

workflow.add_node("detect_intent", detect_intent_node)
workflow.add_node("rag_agent", rag_node)
workflow.add_node("coding_agent", coding_node)
workflow.add_node("general_agent", general_chat_node)

workflow.add_edge(START, "detect_intent")

workflow.add_conditional_edges(
    "detect_intent",
    route_intent,
    {
        "document_search": "rag_agent",
        "coding": "coding_agent",
        "general_chat": "general_agent"
    }
)

workflow.add_edge("rag_agent", END)
workflow.add_edge("coding_agent", END)
workflow.add_edge("general_agent", END)

# COMPILE THE GRAPH
agent_graph = workflow.compile()

# SAVE LOCAL VISUAL (graph_brain.png)
try:
    with open("graph_brain.png", "wb") as f:
        f.write(agent_graph.get_graph().draw_mermaid_png())
    print("✅ Success: Graph brain saved as graph_brain.png!")
except Exception as e:
    print(f"⚠️ Could not save graph image: {e}")

# ==========================================
# 6. Wrapper Entry Point
# ==========================================
@traceable
def agent_brain(user_input: str) -> str:
    """Wrapper to invoke the LangGraph and return the response."""
    initial_state = {
        "user_input": user_input,
        "messages": [],
        "intent": "",
        "response": ""
    }
    result = agent_graph.invoke(initial_state)
    return result["response"]
