"""
Shared Type Definitions — SINGLE SOURCE OF TRUTH
All agents reference these models. Do not duplicate.
"""

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ============================================================
# Enums
# ============================================================

class MessageRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"


class ErrorCode(str, Enum):
    VALIDATION_ERROR = "VALIDATION_ERROR"
    NOT_FOUND = "NOT_FOUND"
    UNAUTHORIZED = "UNAUTHORIZED"
    FORBIDDEN = "FORBIDDEN"
    INTERNAL_ERROR = "INTERNAL_ERROR"
    RATE_LIMITED = "RATE_LIMITED"


# ============================================================
# Core Entities
# ============================================================

class Session(BaseModel):
    id: UUID
    title: str
    created_at: datetime
    updated_at: datetime


class Message(BaseModel):
    id: UUID
    session_id: UUID
    role: MessageRole
    content: str
    created_at: datetime


# ============================================================
# Request Shapes
# ============================================================

class CreateSessionRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)


class CreateMessageRequest(BaseModel):
    role: MessageRole
    content: str = Field(..., min_length=1)


# ============================================================
# Response Shapes
# ============================================================

class MessageListResponse(BaseModel):
    messages: list[Message]
    total: int


class PaginationMeta(BaseModel):
    total: int
    offset: int
    limit: int


# ============================================================
# Error Envelope
# ============================================================

class ErrorDetail(BaseModel):
    field: Optional[str] = None
    message: str


class ApiError(BaseModel):
    error: str
    code: ErrorCode
    details: list[ErrorDetail] = []


# ============================================================
# Constants
# ============================================================

API_BASE = "/api/v1"
DEFAULT_PAGE_SIZE = 50
MAX_PAGE_SIZE = 100
