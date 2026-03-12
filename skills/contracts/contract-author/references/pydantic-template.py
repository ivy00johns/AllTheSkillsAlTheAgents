"""
Shared Type Definitions — SINGLE SOURCE OF TRUTH
All agents reference these models. Do not duplicate.

Naming convention: Python uses snake_case internally. The API wire format
uses camelCase. ContractModel's alias_generator handles the transform so
both sides agree on the serialized JSON shape.
"""

from datetime import datetime
from enum import Enum
from typing import Literal, Optional, Union
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


def to_camel(string: str) -> str:
    components = string.split("_")
    return components[0] + "".join(x.title() for x in components[1:])


class ContractModel(BaseModel):
    """Base for all contract models. Serializes to camelCase for API compatibility."""
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
    )


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

class Session(ContractModel):
    id: UUID
    title: str
    created_at: datetime
    updated_at: datetime


class Message(ContractModel):
    id: UUID
    session_id: UUID
    role: MessageRole
    content: str
    created_at: datetime


# ============================================================
# Request Shapes
# ============================================================

class CreateSessionRequest(ContractModel):
    title: str = Field(..., min_length=1, max_length=200)


class CreateMessageRequest(ContractModel):
    role: MessageRole
    content: str = Field(..., min_length=1)


# ============================================================
# Response Shapes
# ============================================================

class PaginatedResponse(ContractModel):
    """Generic paginated response. Use: PaginatedResponse with items as the entity list."""
    items: list  # Override with specific type in actual usage
    total: int
    offset: int
    limit: int


class MessageListResponse(PaginatedResponse):
    items: list[Message]


# ============================================================
# Error Envelope
# ============================================================

class ErrorDetail(ContractModel):
    field: Optional[str] = None
    message: str


class ApiError(ContractModel):
    error: str
    code: ErrorCode
    details: list[ErrorDetail] = []


# ============================================================
# SSE Event Types (for streaming endpoints)
# ============================================================

class ChunkEvent(ContractModel):
    type: Literal["chunk"] = "chunk"
    content: str


class DoneEvent(ContractModel):
    type: Literal["done"] = "done"
    message_id: UUID
    full_content: str


class ErrorEvent(ContractModel):
    type: Literal["error"] = "error"
    error: str
    code: str


StreamEvent = Union[ChunkEvent, DoneEvent, ErrorEvent]


# ============================================================
# Constants
# ============================================================

API_BASE = "/api/v1"
DEFAULT_PAGE_SIZE = 50
MAX_PAGE_SIZE = 100
