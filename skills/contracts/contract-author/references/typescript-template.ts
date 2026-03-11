/**
 * Shared Type Definitions — SINGLE SOURCE OF TRUTH
 * All agents reference these types. Do not duplicate.
 */

// ============================================================
// Enums and Constants
// ============================================================

export type MessageRole = "user" | "assistant";

export type ErrorCode =
  | "VALIDATION_ERROR"
  | "NOT_FOUND"
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "INTERNAL_ERROR"
  | "RATE_LIMITED";

export const API_BASE = "/api/v1";
export const DEFAULT_PAGE_SIZE = 50;
export const MAX_PAGE_SIZE = 100;

// ============================================================
// Core Entities
// ============================================================

export interface Session {
  id: string;           // UUID v4
  title: string;
  createdAt: string;    // ISO 8601
  updatedAt: string;    // ISO 8601
}

export interface Message {
  id: string;           // UUID v4
  sessionId: string;    // UUID v4
  role: MessageRole;
  content: string;
  createdAt: string;    // ISO 8601
}

// ============================================================
// Request Shapes
// ============================================================

export interface CreateSessionRequest {
  title: string;        // required, 1-200 chars
}

export interface CreateMessageRequest {
  role: MessageRole;
  content: string;      // required, min 1 char
}

// ============================================================
// Response Shapes
// ============================================================

export interface MessageListResponse {
  messages: Message[];
  total: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  offset: number;
  limit: number;
}

// ============================================================
// Error Envelope
// ============================================================

export interface ErrorDetail {
  field?: string;
  message: string;
}

export interface ApiError {
  error: string;
  code: ErrorCode;
  details: ErrorDetail[];
}

// ============================================================
// SSE Event Types (if applicable)
// ============================================================

export interface ChunkEvent {
  content: string;
}

export interface DoneEvent {
  messageId: string;
  fullContent: string;
}

export interface ErrorEvent {
  error: string;
  code: string;
}
