from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services import gemini_client

router = APIRouter(prefix="/api/chat", tags=["chat"])


class ChatQuestion(BaseModel):
    question: str


class ChatAnswer(BaseModel):
    answer: str


@router.post("")
def ask_chat(payload: ChatQuestion) -> ChatAnswer:
    """Answers one question about every saved video result via Gemini.
    Stateless: each call re-sends the full current results snapshot, no
    conversation history is kept server-side (see services/gemini_client.py)."""
    question = payload.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="question must not be empty")
    try:
        answer = gemini_client.ask(question)
    except RuntimeError as error:
        # Config/network/API errors (missing key, Gemini down, ...) -- not the
        # caller's fault, so 502 rather than 400/500.
        raise HTTPException(status_code=502, detail=str(error))
    return ChatAnswer(answer=answer)
