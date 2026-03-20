# Phase 5 -- Code Review + Contract Compliance

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Dependencies:** Phase 2 (Core Visualization Blocks)
**Duration:** 2 weeks
**Deliverables:** diff-viewer block, contract-compliance block, file-tree block, cross-block communication

---

## 1. Overview

Phase 5 builds the three blocks that enable human review of agent-produced code changes and contract conformance. These blocks work together as an integrated review surface:

- **diff-viewer** -- Monaco DiffEditor showing before/after code changes per agent
- **contract-compliance** -- endpoint-by-endpoint comparison of OpenAPI contracts against agent implementations
- **file-tree** -- virtualized file explorer with real-time agent modification indicators

The core interaction loop: the user sees agent-colored files in the tree, clicks one, the diff viewer loads that file's changes, and the contract compliance panel shows whether those changes satisfy the integration contract.

**Why this phase matters:** The orchestrator enforces exclusive file ownership and contract-first builds. This phase makes those constraints _visible_ -- surfacing violations, schema mismatches, and unauthorized edits before they reach QA gates.

---

## 2. Block: diff-viewer

### 2.1 Purpose

Display before/after code diffs for agent-produced changes using `@monaco-editor/react` DiffEditor. Support both side-by-side and unified diff modes, streaming code output, inline annotations, and per-change accept/reject decisions.

### 2.2 Critical Constraint: Single Editor Instance

Monaco's DiffEditor uses global state (theme, language services, keybindings). Creating multiple editors causes memory leaks, conflicting registrations, and degraded intellisense. This is a hard architectural constraint, not a suggestion.

**Rule:** One `DiffEditor` component mounts at application startup. File selection swaps `ITextModel` pairs via `editor.setModel()`. The editor is never destroyed and recreated.

### 2.3 Model Management

```typescript
// models/monaco-model-cache.ts
import * as monaco from 'monaco-editor';

interface ModelPair {
  original: monaco.editor.ITextModel;
  modified: monaco.editor.ITextModel;
  language: string;
  lastAccessed: number;
}

class MonacoModelCache {
  private cache = new Map<string, ModelPair>();
  private readonly MAX_MODELS = 100; // Evict LRU beyond this

  /**
   * Get or create a model pair for a file.
   * fileId is typically `${agentId}:${filePath}`.
   */
  getOrCreate(
    fileId: string,
    originalContent: string,
    modifiedContent: string,
    filePath: string
  ): ModelPair {
    const existing = this.cache.get(fileId);
    if (existing) {
      existing.lastAccessed = Date.now();
      return existing;
    }

    // Evict LRU if at capacity
    if (this.cache.size >= this.MAX_MODELS) {
      this.evictLRU();
    }

    const language = this.detectLanguage(filePath);
    const originalUri = monaco.Uri.parse(`original:///${fileId}`);
    const modifiedUri = monaco.Uri.parse(`modified:///${fileId}`);

    const pair: ModelPair = {
      original: monaco.editor.createModel(originalContent, language, originalUri),
      modified: monaco.editor.createModel(modifiedContent, language, modifiedUri),
      language,
      lastAccessed: Date.now(),
    };

    this.cache.set(fileId, pair);
    return pair;
  }

  /**
   * Update modified content for streaming code output.
   * Does NOT recreate the model -- appends or replaces value in place.
   */
  updateModified(fileId: string, content: string): void {
    const pair = this.cache.get(fileId);
    if (pair) {
      pair.modified.setValue(content);
      pair.lastAccessed = Date.now();
    }
  }

  /**
   * Append content for streaming output (stream-monaco pattern).
   * Uses pushEditOperations to avoid full model replacement.
   */
  appendModified(fileId: string, chunk: string): void {
    const pair = this.cache.get(fileId);
    if (!pair) return;

    const model = pair.modified;
    const lastLine = model.getLineCount();
    const lastColumn = model.getLineMaxColumn(lastLine);

    model.pushEditOperations(
      [],
      [{
        range: new monaco.Range(lastLine, lastColumn, lastLine, lastColumn),
        text: chunk,
      }],
      () => null
    );

    pair.lastAccessed = Date.now();
  }

  /**
   * Dispose a specific model pair (file closed or agent completed).
   */
  dispose(fileId: string): void {
    const pair = this.cache.get(fileId);
    if (pair) {
      pair.original.dispose();
      pair.modified.dispose();
      this.cache.delete(fileId);
    }
  }

  /**
   * Dispose all models (block destroyed or build completed).
   */
  disposeAll(): void {
    for (const [fileId, pair] of this.cache) {
      pair.original.dispose();
      pair.modified.dispose();
    }
    this.cache.clear();
  }

  private evictLRU(): void {
    let oldest: string | null = null;
    let oldestTime = Infinity;

    for (const [fileId, pair] of this.cache) {
      if (pair.lastAccessed < oldestTime) {
        oldestTime = pair.lastAccessed;
        oldest = fileId;
      }
    }

    if (oldest) {
      this.dispose(oldest);
    }
  }

  private detectLanguage(filePath: string): string {
    const ext = filePath.split('.').pop()?.toLowerCase() ?? '';
    const extMap: Record<string, string> = {
      ts: 'typescript', tsx: 'typescript',
      js: 'javascript', jsx: 'javascript',
      py: 'python',
      rs: 'rust',
      go: 'go',
      java: 'java',
      rb: 'ruby',
      css: 'css', scss: 'scss', less: 'less',
      html: 'html', htm: 'html',
      json: 'json',
      yaml: 'yaml', yml: 'yaml',
      md: 'markdown',
      sql: 'sql',
      sh: 'shell', bash: 'shell', zsh: 'shell',
      toml: 'toml',
      xml: 'xml',
      dockerfile: 'dockerfile',
      graphql: 'graphql', gql: 'graphql',
      proto: 'protobuf',
      swift: 'swift',
      kt: 'kotlin',
      c: 'c', h: 'c',
      cpp: 'cpp', hpp: 'cpp', cc: 'cpp',
      cs: 'csharp',
    };
    return extMap[ext] ?? 'plaintext';
  }
}

export const modelCache = new MonacoModelCache();
```

### 2.4 Jotai State Atoms

```typescript
// atoms/diff-viewer-atoms.ts
import { atom } from 'jotai';

export interface DiffAnnotation {
  id: string;
  lineNumber: number;        // Line in modified content
  side: 'original' | 'modified';
  text: string;
  author: string;            // Agent ID or human reviewer
  timestamp: number;
  severity?: 'info' | 'warning' | 'error';
}

export interface FileChange {
  fileId: string;             // `${agentId}:${filePath}`
  filePath: string;
  agentId: string;
  agentRole: string;
  changeType: 'created' | 'modified' | 'deleted';
  additions: number;
  deletions: number;
  purpose?: string;           // Agent-described reason for change
}

export interface ChangeGroup {
  id: string;
  purpose: string;            // "Add user authentication middleware"
  agentId: string;
  agentRole: string;
  files: FileChange[];
}

export type DiffMode = 'side-by-side' | 'unified';

export function createDiffViewerAtoms() {
  return {
    // Currently displayed content
    originalCodeAtom: atom<string>(''),
    modifiedCodeAtom: atom<string>(''),
    languageAtom: atom<string>('plaintext'),

    // File and group selection
    selectedFileAtom: atom<string | null>(null),        // fileId
    selectedGroupAtom: atom<string | null>(null),       // group ID
    fileChangesAtom: atom<FileChange[]>([]),
    changeGroupsAtom: atom<ChangeGroup[]>([]),

    // Display mode
    diffModeAtom: atom<DiffMode>('side-by-side'),

    // Annotations and review
    annotationsAtom: atom<DiffAnnotation[]>([]),
    pendingAnnotationAtom: atom<Partial<DiffAnnotation> | null>(null),

    // Per-change accept/reject state
    changeDecisionsAtom: atom<Map<string, 'accepted' | 'rejected' | 'pending'>>(
      new Map()
    ),

    // Streaming state
    isStreamingAtom: atom<boolean>(false),

    // Editor reference (set once on mount)
    editorRefAtom: atom<monaco.editor.IStandaloneDiffEditor | null>(null),
  };
}
```

### 2.5 DiffViewer Block Component

```tsx
// blocks/diff-viewer/DiffViewerBlock.tsx
import React, { useCallback, useEffect, useRef } from 'react';
import { DiffEditor, DiffOnMount } from '@monaco-editor/react';
import { useAtom, useAtomValue, useSetAtom } from 'jotai';
import { modelCache } from '../../models/monaco-model-cache';
import { useOrchestratorStore } from '../../stores/orchestrator-store';
import type { BlockConfig } from '../../types/blocks';
import type { DiffViewerAtoms } from '../../atoms/diff-viewer-atoms';

interface Props {
  atoms: ReturnType<typeof createDiffViewerAtoms>;
  config: BlockConfig;
}

export const DiffViewerBlock = React.memo(function DiffViewerBlock({ atoms, config }: Props) {
  const editorRef = useRef<monaco.editor.IStandaloneDiffEditor | null>(null);

  const [selectedFile, setSelectedFile] = useAtom(atoms.selectedFileAtom);
  const [diffMode, setDiffMode] = useAtom(atoms.diffModeAtom);
  const fileChanges = useAtomValue(atoms.fileChangesAtom);
  const changeGroups = useAtomValue(atoms.changeGroupsAtom);
  const [selectedGroup, setSelectedGroup] = useAtom(atoms.selectedGroupAtom);
  const annotations = useAtomValue(atoms.annotationsAtom);
  const [changeDecisions, setChangeDecisions] = useAtom(atoms.changeDecisionsAtom);
  const isStreaming = useAtomValue(atoms.isStreamingAtom);

  // Filter files by selected group
  const visibleFiles = selectedGroup
    ? changeGroups.find(g => g.id === selectedGroup)?.files ?? []
    : fileChanges;

  // Mount handler: capture editor reference, configure options
  const handleEditorMount: DiffOnMount = useCallback((editor) => {
    editorRef.current = editor;

    editor.updateOptions({
      readOnly: true,
      renderSideBySide: diffMode === 'side-by-side',
      enableSplitViewResizing: true,
      renderOverviewRuler: true,
      originalEditable: false,
      minimap: { enabled: false },
      scrollBeyondLastLine: false,
      fontSize: 13,
      lineNumbers: 'on',
      wordWrap: 'off',
    });
  }, [diffMode]);

  // Swap models when file selection changes
  useEffect(() => {
    if (!editorRef.current || !selectedFile) return;

    const fileChange = fileChanges.find(f => f.fileId === selectedFile);
    if (!fileChange) return;

    // Models are pre-created and cached when file change events arrive
    const pair = modelCache.getOrCreate(
      fileChange.fileId,
      '', // Original content loaded asynchronously
      '', // Modified content loaded asynchronously
      fileChange.filePath
    );

    editorRef.current.setModel({
      original: pair.original,
      modified: pair.modified,
    });
  }, [selectedFile, fileChanges]);

  // Update diff mode without recreating editor
  useEffect(() => {
    if (!editorRef.current) return;
    editorRef.current.updateOptions({
      renderSideBySide: diffMode === 'side-by-side',
    });
  }, [diffMode]);

  // Render inline annotations as decorations
  useEffect(() => {
    if (!editorRef.current) return;

    const modifiedEditor = editorRef.current.getModifiedEditor();
    const decorations = annotations
      .filter(a => a.side === 'modified')
      .map(a => ({
        range: new monaco.Range(a.lineNumber, 1, a.lineNumber, 1),
        options: {
          isWholeLine: true,
          className: `annotation-${a.severity ?? 'info'}`,
          glyphMarginClassName: `annotation-glyph-${a.severity ?? 'info'}`,
          glyphMarginHoverMessage: { value: `**${a.author}:** ${a.text}` },
        },
      }));

    modifiedEditor.deltaDecorations([], decorations);
  }, [annotations]);

  const handleAcceptChange = useCallback((fileId: string) => {
    setChangeDecisions(prev => {
      const next = new Map(prev);
      next.set(fileId, 'accepted');
      return next;
    });
  }, [setChangeDecisions]);

  const handleRejectChange = useCallback((fileId: string) => {
    setChangeDecisions(prev => {
      const next = new Map(prev);
      next.set(fileId, 'rejected');
      return next;
    });
  }, [setChangeDecisions]);

  return (
    <div className="diff-viewer-block flex flex-col h-full">
      {/* Toolbar */}
      <div className="diff-toolbar flex items-center gap-2 px-3 py-2 border-b border-gray-200 bg-gray-50">
        {/* Change group selector */}
        <select
          value={selectedGroup ?? ''}
          onChange={(e) => setSelectedGroup(e.target.value || null)}
          className="text-sm border rounded px-2 py-1"
        >
          <option value="">All changes</option>
          {changeGroups.map(g => (
            <option key={g.id} value={g.id}>
              {g.purpose} ({g.files.length} files)
            </option>
          ))}
        </select>

        {/* File selector */}
        <select
          value={selectedFile ?? ''}
          onChange={(e) => setSelectedFile(e.target.value || null)}
          className="text-sm border rounded px-2 py-1 flex-1 min-w-0"
        >
          <option value="">Select a file...</option>
          {visibleFiles.map(f => (
            <option key={f.fileId} value={f.fileId}>
              {f.filePath} ({f.changeType}, +{f.additions} -{f.deletions})
            </option>
          ))}
        </select>

        {/* Diff mode toggle */}
        <button
          onClick={() => setDiffMode(m => m === 'side-by-side' ? 'unified' : 'side-by-side')}
          className="text-sm px-2 py-1 border rounded hover:bg-gray-100"
        >
          {diffMode === 'side-by-side' ? 'Unified' : 'Split'}
        </button>

        {/* Accept/reject for current file */}
        {selectedFile && (
          <div className="flex gap-1 ml-2">
            <button
              onClick={() => handleAcceptChange(selectedFile)}
              className={`text-sm px-2 py-1 rounded ${
                changeDecisions.get(selectedFile) === 'accepted'
                  ? 'bg-green-600 text-white'
                  : 'border border-green-600 text-green-600 hover:bg-green-50'
              }`}
            >
              Accept
            </button>
            <button
              onClick={() => handleRejectChange(selectedFile)}
              className={`text-sm px-2 py-1 rounded ${
                changeDecisions.get(selectedFile) === 'rejected'
                  ? 'bg-red-600 text-white'
                  : 'border border-red-600 text-red-600 hover:bg-red-50'
              }`}
            >
              Reject
            </button>
          </div>
        )}

        {/* Streaming indicator */}
        {isStreaming && (
          <span className="text-xs text-blue-600 animate-pulse ml-auto">
            Streaming...
          </span>
        )}
      </div>

      {/* Monaco DiffEditor -- single instance, never destroyed */}
      <div className="flex-1 min-h-0">
        <DiffEditor
          theme="vs-dark"
          onMount={handleEditorMount}
          options={{
            readOnly: true,
            renderSideBySide: diffMode === 'side-by-side',
          }}
        />
      </div>
    </div>
  );
});
```

### 2.6 Streaming Code Integration

When an agent is actively writing a file, code appears in the diff viewer in real-time. This uses the `appendModified` method on the model cache, throttled to prevent jank.

```typescript
// services/streaming-diff.ts

/**
 * Throttled streaming integration for Monaco DiffEditor.
 * Batches incoming code chunks into 100ms windows to prevent
 * excessive model mutations and re-renders.
 */
class StreamingDiffManager {
  private buffers = new Map<string, string>();
  private flushTimers = new Map<string, ReturnType<typeof setTimeout>>();
  private readonly THROTTLE_MS = 100;

  onCodeChunk(fileId: string, chunk: string): void {
    const existing = this.buffers.get(fileId) ?? '';
    this.buffers.set(fileId, existing + chunk);

    if (!this.flushTimers.has(fileId)) {
      this.flushTimers.set(fileId, setTimeout(() => {
        this.flush(fileId);
      }, this.THROTTLE_MS));
    }
  }

  private flush(fileId: string): void {
    const buffered = this.buffers.get(fileId);
    if (buffered) {
      modelCache.appendModified(fileId, buffered);
      this.buffers.delete(fileId);
    }
    this.flushTimers.delete(fileId);
  }

  /**
   * Flush all remaining buffers (agent completed writing).
   */
  flushAll(): void {
    for (const [fileId] of this.buffers) {
      this.flush(fileId);
    }
  }

  dispose(): void {
    for (const timer of this.flushTimers.values()) {
      clearTimeout(timer);
    }
    this.flushTimers.clear();
    this.buffers.clear();
  }
}

export const streamingDiff = new StreamingDiffManager();
```

### 2.7 Agent Change Grouping

Following the Devin Review pattern, changes are grouped by purpose rather than presented file-by-file. Agents emit a `change_group` metadata event when they begin a logical unit of work.

```typescript
// services/change-grouper.ts

interface RawFileChange {
  agentId: string;
  agentRole: string;
  filePath: string;
  changeType: 'created' | 'modified' | 'deleted';
  originalContent: string;
  modifiedContent: string;
  purpose?: string;         // From agent's change_group event
  groupId?: string;         // From agent's change_group event
  timestamp: number;
}

/**
 * Groups file changes by agent-declared purpose.
 * Falls back to temporal grouping (changes within 30s of each other)
 * when agents don't declare explicit groups.
 */
function groupChanges(changes: RawFileChange[]): ChangeGroup[] {
  const explicitGroups = new Map<string, ChangeGroup>();
  const ungrouped: RawFileChange[] = [];

  // First pass: collect explicitly grouped changes
  for (const change of changes) {
    if (change.groupId && change.purpose) {
      if (!explicitGroups.has(change.groupId)) {
        explicitGroups.set(change.groupId, {
          id: change.groupId,
          purpose: change.purpose,
          agentId: change.agentId,
          agentRole: change.agentRole,
          files: [],
        });
      }
      explicitGroups.get(change.groupId)!.files.push(toFileChange(change));
    } else {
      ungrouped.push(change);
    }
  }

  // Second pass: temporal grouping for ungrouped changes
  const temporalGroups = temporalGroup(ungrouped, 30_000); // 30s window

  return [...explicitGroups.values(), ...temporalGroups];
}

function temporalGroup(changes: RawFileChange[], windowMs: number): ChangeGroup[] {
  if (changes.length === 0) return [];

  const sorted = [...changes].sort((a, b) => a.timestamp - b.timestamp);
  const groups: ChangeGroup[] = [];
  let current: RawFileChange[] = [sorted[0]];

  for (let i = 1; i < sorted.length; i++) {
    if (
      sorted[i].timestamp - sorted[i - 1].timestamp <= windowMs &&
      sorted[i].agentId === sorted[i - 1].agentId
    ) {
      current.push(sorted[i]);
    } else {
      groups.push(toChangeGroup(current));
      current = [sorted[i]];
    }
  }

  if (current.length > 0) {
    groups.push(toChangeGroup(current));
  }

  return groups;
}

function toChangeGroup(changes: RawFileChange[]): ChangeGroup {
  const first = changes[0];
  return {
    id: `temporal_${first.agentId}_${first.timestamp}`,
    purpose: `${changes.length} file(s) changed by ${first.agentRole}`,
    agentId: first.agentId,
    agentRole: first.agentRole,
    files: changes.map(toFileChange),
  };
}

function toFileChange(raw: RawFileChange): FileChange {
  const additions = countLines(raw.modifiedContent) - countLines(raw.originalContent);
  return {
    fileId: `${raw.agentId}:${raw.filePath}`,
    filePath: raw.filePath,
    agentId: raw.agentId,
    agentRole: raw.agentRole,
    changeType: raw.changeType,
    additions: Math.max(0, additions),
    deletions: Math.max(0, -additions),
    purpose: raw.purpose,
  };
}
```

---

## 3. Block: contract-compliance

### 3.1 Purpose

Visualize how well each agent's implementation matches the integration contracts. Contracts are defined during Phase 0 (contract generation) and agents are scored against them by the QE agent. This block makes the conformance visible at endpoint granularity.

### 3.2 Data Model

```typescript
// types/contract-compliance.ts

export type ComplianceStatus = 'match' | 'mismatch' | 'partial' | 'not_implemented';
export type ViolationSeverity = 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';

export interface EndpointCompliance {
  id: string;
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
  contractSource: string;           // OpenAPI spec file path
  implementationSource: string;     // Agent-produced file path

  // Schema comparison results
  requestSchemaMatch: ComplianceStatus;
  responseSchemaMatch: ComplianceStatus;
  statusCodesMatch: ComplianceStatus;
  headersMatch: ComplianceStatus;

  // Overall status (worst of above)
  overallStatus: ComplianceStatus;

  // Diff details (populated when expanded)
  requestSchemaDiff?: SchemaDiff;
  responseSchemaDiff?: SchemaDiff;
  statusCodesDiff?: { expected: number[]; actual: number[] };
  headersDiff?: { expected: string[]; actual: string[]; missing: string[] };

  // Owning agent
  agentId: string;
  agentRole: string;
}

export interface SchemaDiff {
  expected: object;               // From OpenAPI contract
  actual: object;                 // From implementation (parsed from code)
  missingFields: string[];        // Fields in contract but not implementation
  extraFields: string[];          // Fields in implementation but not contract
  typeMismatches: TypeMismatch[];
}

export interface TypeMismatch {
  fieldPath: string;              // "response.body.user.email"
  expectedType: string;
  actualType: string;
}

export interface ContractViolation {
  id: string;
  severity: ViolationSeverity;
  category: 'schema' | 'security' | 'performance' | 'migration' | 'ownership';
  message: string;
  endpointId?: string;            // Links to EndpointCompliance
  filePath?: string;              // Links to diff viewer
  agentId: string;
  agentRole: string;
  suggestion?: string;            // Recommended fix
  autoFixable: boolean;
}

export interface ComplianceScores {
  contract_conformance: number;   // 1-5 scale (from QA report)
  security: number;
  performance: number;
  overall: number;                // Weighted average
}

export interface SecurityCheck {
  id: string;
  name: string;                   // "Auth middleware present", "SQL injection guard", etc.
  status: 'pass' | 'fail' | 'warning' | 'skipped';
  details: string;
  filePath?: string;
}

export interface MigrationValidation {
  id: string;
  tableName: string;
  status: ComplianceStatus;
  expectedColumns: string[];
  actualColumns: string[];
  missingColumns: string[];
  extraColumns: string[];
  typeMismatches: TypeMismatch[];
}
```

### 3.3 Jotai State Atoms

```typescript
// atoms/contract-compliance-atoms.ts
import { atom } from 'jotai';

export function createContractComplianceAtoms() {
  return {
    // Endpoint compliance data
    endpointsAtom: atom<EndpointCompliance[]>([]),
    selectedEndpointAtom: atom<string | null>(null),
    expandedRowsAtom: atom<Set<string>>(new Set()),

    // Scores (from QA report)
    scoresAtom: atom<ComplianceScores | null>(null),

    // Violations
    violationsAtom: atom<ContractViolation[]>([]),
    violationFilterAtom: atom<ViolationSeverity | 'all'>('all'),

    // Security checks
    securityChecksAtom: atom<SecurityCheck[]>([]),

    // Migration validation
    migrationsAtom: atom<MigrationValidation[]>([]),

    // Last check timestamp
    lastCheckAtom: atom<number | null>(null),

    // Loading state
    isLoadingAtom: atom<boolean>(false),
  };
}
```

### 3.4 Endpoint Matching Algorithm

The compliance checker compares OpenAPI contract definitions against the agent's actual implementation. This runs in the QE agent but the result is rendered in this block.

```typescript
// services/contract-matcher.ts

/**
 * Match OpenAPI endpoints against agent implementation.
 *
 * Strategy:
 * 1. Parse OpenAPI spec to extract all endpoints (method + path + schemas)
 * 2. Scan agent implementation files for route definitions (Express, FastAPI, etc.)
 * 3. For each contract endpoint, find the matching implementation
 * 4. Compare request/response schemas via structural matching
 *
 * Structural matching rules:
 * - MATCH: All required fields present with correct types
 * - PARTIAL: Some required fields missing, or types differ but are coercible
 * - MISMATCH: Required fields missing with incompatible types
 * - NOT_IMPLEMENTED: No matching route found in implementation
 */

interface OpenAPIEndpoint {
  method: string;
  path: string;                      // "/api/users/{id}"
  operationId: string;
  requestBody?: JSONSchema;
  responses: Record<string, { schema?: JSONSchema }>;
  parameters?: OpenAPIParameter[];
}

function matchEndpoints(
  contractEndpoints: OpenAPIEndpoint[],
  implementedRoutes: ImplementedRoute[],
): EndpointCompliance[] {
  return contractEndpoints.map(contract => {
    // Normalize paths: "/api/users/{id}" matches "/api/users/:id"
    const impl = implementedRoutes.find(r =>
      r.method.toUpperCase() === contract.method.toUpperCase() &&
      normalizePath(r.path) === normalizePath(contract.path)
    );

    if (!impl) {
      return {
        id: `${contract.method}_${contract.path}`,
        method: contract.method as EndpointCompliance['method'],
        path: contract.path,
        contractSource: '', // Populated from context
        implementationSource: '',
        requestSchemaMatch: 'not_implemented',
        responseSchemaMatch: 'not_implemented',
        statusCodesMatch: 'not_implemented',
        headersMatch: 'not_implemented',
        overallStatus: 'not_implemented',
        agentId: '',
        agentRole: '',
      };
    }

    const requestMatch = compareSchemas(
      contract.requestBody,
      impl.requestSchema
    );

    const responseMatch = compareSchemas(
      contract.responses['200']?.schema,
      impl.responseSchema
    );

    const statusMatch = compareStatusCodes(
      Object.keys(contract.responses).map(Number),
      impl.statusCodes
    );

    const overallStatus = worstStatus([
      requestMatch.status,
      responseMatch.status,
      statusMatch,
    ]);

    return {
      id: `${contract.method}_${contract.path}`,
      method: contract.method as EndpointCompliance['method'],
      path: contract.path,
      contractSource: contract.operationId,
      implementationSource: impl.filePath,
      requestSchemaMatch: requestMatch.status,
      responseSchemaMatch: responseMatch.status,
      statusCodesMatch: statusMatch,
      headersMatch: 'match', // Simplified: full header matching in v2
      overallStatus,
      requestSchemaDiff: requestMatch.diff,
      responseSchemaDiff: responseMatch.diff,
      agentId: impl.agentId,
      agentRole: impl.agentRole,
    };
  });
}

function normalizePath(path: string): string {
  // Convert Express ":param" to OpenAPI "{param}" for comparison
  return path.replace(/:(\w+)/g, '{$1}').toLowerCase();
}

function worstStatus(statuses: ComplianceStatus[]): ComplianceStatus {
  const priority: ComplianceStatus[] = [
    'not_implemented', 'mismatch', 'partial', 'match'
  ];
  for (const status of priority) {
    if (statuses.includes(status)) return status;
  }
  return 'match';
}
```

### 3.5 Contract Compliance Block Component

```tsx
// blocks/contract-compliance/ContractComplianceBlock.tsx
import React, { useCallback } from 'react';
import { useAtom, useAtomValue } from 'jotai';
import { useOrchestratorStore } from '../../stores/orchestrator-store';
import type { EndpointCompliance, ContractViolation, ViolationSeverity } from '../../types/contract-compliance';

const STATUS_COLORS: Record<string, string> = {
  match: 'bg-green-100 text-green-800',
  mismatch: 'bg-red-100 text-red-800',
  partial: 'bg-yellow-100 text-yellow-800',
  not_implemented: 'bg-gray-100 text-gray-500',
};

const SEVERITY_COLORS: Record<ViolationSeverity, string> = {
  CRITICAL: 'bg-red-600 text-white',
  HIGH: 'bg-red-100 text-red-800',
  MEDIUM: 'bg-yellow-100 text-yellow-800',
  LOW: 'bg-blue-100 text-blue-800',
};

const METHOD_COLORS: Record<string, string> = {
  GET: 'text-blue-600',
  POST: 'text-green-600',
  PUT: 'text-orange-600',
  PATCH: 'text-yellow-600',
  DELETE: 'text-red-600',
};

export const ContractComplianceBlock = React.memo(function ContractComplianceBlock({
  atoms,
  config,
}: {
  atoms: ReturnType<typeof createContractComplianceAtoms>;
  config: BlockConfig;
}) {
  const endpoints = useAtomValue(atoms.endpointsAtom);
  const scores = useAtomValue(atoms.scoresAtom);
  const violations = useAtomValue(atoms.violationsAtom);
  const [expandedRows, setExpandedRows] = useAtom(atoms.expandedRowsAtom);
  const [violationFilter, setViolationFilter] = useAtom(atoms.violationFilterAtom);
  const securityChecks = useAtomValue(atoms.securityChecksAtom);
  const lastCheck = useAtomValue(atoms.lastCheckAtom);

  // Cross-block communication: clicking a violation opens the file in diff-viewer
  const selectAgent = useOrchestratorStore(s => s.selectAgent);

  const toggleRow = useCallback((id: string) => {
    setExpandedRows(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, [setExpandedRows]);

  const navigateToDiff = useCallback((filePath: string, agentId: string) => {
    // Dispatch cross-block action: Zustand action updates selectedFile
    // which diff-viewer listens to
    useOrchestratorStore.getState().openFileInDiffViewer(agentId, filePath);
  }, []);

  const filteredViolations = violationFilter === 'all'
    ? violations
    : violations.filter(v => v.severity === violationFilter);

  return (
    <div className="contract-compliance-block flex flex-col h-full overflow-hidden">
      {/* Score Header */}
      {scores && (
        <div className="score-header flex items-center gap-4 px-4 py-3 border-b bg-gray-50">
          <ScoreBadge label="Contract" score={scores.contract_conformance} />
          <ScoreBadge label="Security" score={scores.security} />
          <ScoreBadge label="Performance" score={scores.performance} />
          <div className="ml-auto text-xs text-gray-500">
            Last checked: {lastCheck ? new Date(lastCheck).toLocaleTimeString() : 'Never'}
          </div>
        </div>
      )}

      {/* Endpoint Table */}
      <div className="flex-1 overflow-auto">
        <table className="w-full text-sm">
          <thead className="bg-gray-100 sticky top-0">
            <tr>
              <th className="px-3 py-2 text-left">Method</th>
              <th className="px-3 py-2 text-left">Path</th>
              <th className="px-3 py-2 text-center">Request</th>
              <th className="px-3 py-2 text-center">Response</th>
              <th className="px-3 py-2 text-center">Status Codes</th>
              <th className="px-3 py-2 text-center">Overall</th>
            </tr>
          </thead>
          <tbody>
            {endpoints.map(ep => (
              <React.Fragment key={ep.id}>
                <tr
                  className="border-b hover:bg-gray-50 cursor-pointer"
                  onClick={() => toggleRow(ep.id)}
                >
                  <td className={`px-3 py-2 font-mono font-bold ${METHOD_COLORS[ep.method] ?? ''}`}>
                    {ep.method}
                  </td>
                  <td className="px-3 py-2 font-mono text-xs">{ep.path}</td>
                  <td className="px-3 py-2 text-center">
                    <StatusBadge status={ep.requestSchemaMatch} />
                  </td>
                  <td className="px-3 py-2 text-center">
                    <StatusBadge status={ep.responseSchemaMatch} />
                  </td>
                  <td className="px-3 py-2 text-center">
                    <StatusBadge status={ep.statusCodesMatch} />
                  </td>
                  <td className="px-3 py-2 text-center">
                    <StatusBadge status={ep.overallStatus} />
                  </td>
                </tr>

                {/* Expanded row: schema diffs */}
                {expandedRows.has(ep.id) && (
                  <tr>
                    <td colSpan={6} className="px-4 py-3 bg-gray-50">
                      <EndpointDetail
                        endpoint={ep}
                        onNavigateToDiff={navigateToDiff}
                      />
                    </td>
                  </tr>
                )}
              </React.Fragment>
            ))}
          </tbody>
        </table>
      </div>

      {/* Violation Panel */}
      <div className="border-t">
        <div className="flex items-center gap-2 px-3 py-2 bg-gray-50">
          <span className="text-sm font-medium">Violations ({filteredViolations.length})</span>
          <select
            value={violationFilter}
            onChange={e => setViolationFilter(e.target.value as ViolationSeverity | 'all')}
            className="text-xs border rounded px-1 py-0.5"
          >
            <option value="all">All</option>
            <option value="CRITICAL">Critical</option>
            <option value="HIGH">High</option>
            <option value="MEDIUM">Medium</option>
            <option value="LOW">Low</option>
          </select>
        </div>
        <div className="max-h-48 overflow-auto">
          {filteredViolations.map(v => (
            <ViolationRow
              key={v.id}
              violation={v}
              onNavigate={() => {
                if (v.filePath) navigateToDiff(v.filePath, v.agentId);
              }}
            />
          ))}
        </div>
      </div>
    </div>
  );
});

// Subcomponents

function ScoreBadge({ label, score }: { label: string; score: number }) {
  const color = score >= 4 ? 'text-green-600' : score >= 3 ? 'text-yellow-600' : 'text-red-600';
  return (
    <div className="flex items-center gap-1">
      <span className="text-xs text-gray-500">{label}:</span>
      <span className={`font-bold ${color}`}>{score.toFixed(1)}/5</span>
    </div>
  );
}

function StatusBadge({ status }: { status: ComplianceStatus }) {
  return (
    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_COLORS[status]}`}>
      {status.replace('_', ' ')}
    </span>
  );
}

function ViolationRow({
  violation,
  onNavigate,
}: {
  violation: ContractViolation;
  onNavigate: () => void;
}) {
  return (
    <div className="flex items-start gap-2 px-3 py-2 border-b border-gray-100 hover:bg-gray-50">
      <span className={`px-1.5 py-0.5 rounded text-xs font-bold ${SEVERITY_COLORS[violation.severity]}`}>
        {violation.severity}
      </span>
      <div className="flex-1 min-w-0">
        <p className="text-sm">{violation.message}</p>
        {violation.suggestion && (
          <p className="text-xs text-gray-500 mt-0.5">Fix: {violation.suggestion}</p>
        )}
      </div>
      {violation.filePath && (
        <button
          onClick={onNavigate}
          className="text-xs text-blue-600 hover:underline whitespace-nowrap"
        >
          View diff
        </button>
      )}
    </div>
  );
}

function EndpointDetail({
  endpoint,
  onNavigateToDiff,
}: {
  endpoint: EndpointCompliance;
  onNavigateToDiff: (filePath: string, agentId: string) => void;
}) {
  return (
    <div className="space-y-3">
      {/* Request schema diff */}
      {endpoint.requestSchemaDiff && (
        <div>
          <h4 className="text-xs font-semibold mb-1">Request Schema Diff</h4>
          <SchemaDiffDisplay diff={endpoint.requestSchemaDiff} />
        </div>
      )}

      {/* Response schema diff */}
      {endpoint.responseSchemaDiff && (
        <div>
          <h4 className="text-xs font-semibold mb-1">Response Schema Diff</h4>
          <SchemaDiffDisplay diff={endpoint.responseSchemaDiff} />
        </div>
      )}

      {/* Status codes diff */}
      {endpoint.statusCodesDiff && (
        <div>
          <h4 className="text-xs font-semibold mb-1">Status Codes</h4>
          <p className="text-xs">
            Expected: {endpoint.statusCodesDiff.expected.join(', ')} |
            Actual: {endpoint.statusCodesDiff.actual.join(', ')}
          </p>
        </div>
      )}

      {/* Link to implementation file */}
      {endpoint.implementationSource && (
        <button
          onClick={() => onNavigateToDiff(endpoint.implementationSource, endpoint.agentId)}
          className="text-xs text-blue-600 hover:underline"
        >
          Open {endpoint.implementationSource} in diff viewer
        </button>
      )}
    </div>
  );
}
```

### 3.6 OpenAPI Schema Validation

```typescript
// services/schema-validator.ts
import Ajv from 'ajv';

const ajv = new Ajv({ allErrors: true, strict: false });

interface SchemaComparisonResult {
  status: ComplianceStatus;
  diff?: SchemaDiff;
}

/**
 * Compare an expected JSON schema (from OpenAPI) against an actual schema
 * (inferred from agent implementation).
 *
 * Uses structural comparison, not validation. Two schemas are compared
 * by their required fields, types, and nested structures.
 */
function compareSchemas(
  expected: JSONSchema | undefined,
  actual: JSONSchema | undefined
): SchemaComparisonResult {
  if (!expected && !actual) {
    return { status: 'match' };
  }

  if (!expected) {
    // Implementation has a schema where contract doesn't -- partial match
    return { status: 'partial' };
  }

  if (!actual) {
    return {
      status: 'not_implemented',
      diff: {
        expected: expected as object,
        actual: {},
        missingFields: extractFieldPaths(expected),
        extraFields: [],
        typeMismatches: [],
      },
    };
  }

  const expectedFields = extractFieldPaths(expected);
  const actualFields = extractFieldPaths(actual);

  const missingFields = expectedFields.filter(f => !actualFields.includes(f));
  const extraFields = actualFields.filter(f => !expectedFields.includes(f));
  const typeMismatches = findTypeMismatches(expected, actual);

  if (missingFields.length === 0 && typeMismatches.length === 0) {
    return { status: 'match' };
  }

  const missingRequired = missingFields.filter(f =>
    isRequiredField(expected, f)
  );

  if (missingRequired.length > 0 || typeMismatches.length > 0) {
    return {
      status: 'mismatch',
      diff: {
        expected: expected as object,
        actual: actual as object,
        missingFields,
        extraFields,
        typeMismatches,
      },
    };
  }

  return {
    status: 'partial',
    diff: {
      expected: expected as object,
      actual: actual as object,
      missingFields,
      extraFields,
      typeMismatches,
    },
  };
}
```

---

## 4. Block: file-tree

### 4.1 Purpose

Display the project file system with real-time agent modification indicators, color-coded ownership, and file status icons. Clicking a file opens it in the diff-viewer block.

### 4.2 Jotai State Atoms

```typescript
// atoms/file-tree-atoms.ts
import { atom } from 'jotai';

export type FileStatus = 'unmodified' | 'modified' | 'created' | 'deleted' | 'conflict';
export type GitStatus = 'staged' | 'unstaged' | 'untracked' | 'clean';
export type FilterMode = 'all' | 'modified_only' | 'by_agent';

export interface FileTreeNode {
  id: string;                       // Full file path
  name: string;                     // File or directory name
  isDirectory: boolean;
  children?: FileTreeNode[];

  // Agent metadata
  ownerAgentRole?: string;          // Which agent role owns this directory
  modifyingAgentId?: string | null; // Agent currently modifying this file (null = idle)
  fileStatus: FileStatus;
  gitStatus: GitStatus;

  // For rendering
  agentColor?: string;              // CSS color for the owning agent
}

export function createFileTreeAtoms() {
  return {
    // Tree data
    treeDataAtom: atom<FileTreeNode[]>([]),

    // Expansion state (Set of node IDs that are expanded)
    expandedNodesAtom: atom<Set<string>>(new Set()),

    // Files actively being modified by agents (file path -> agent ID)
    activeAgentFilesAtom: atom<Map<string, string>>(new Map()),

    // Selection
    selectedFileAtom: atom<string | null>(null),

    // Filtering
    filterModeAtom: atom<FilterMode>('all'),
    filterAgentAtom: atom<string | null>(null),

    // Search
    searchQueryAtom: atom<string>(''),
  };
}
```

### 4.3 Agent Color Mapping

Each of the 9 agent roles gets a distinct, accessible color:

```typescript
// constants/agent-colors.ts

export const AGENT_ROLE_COLORS: Record<string, { bg: string; text: string; border: string }> = {
  'backend-agent':        { bg: 'bg-blue-100',    text: 'text-blue-800',    border: 'border-blue-400' },
  'frontend-agent':       { bg: 'bg-green-100',   text: 'text-green-800',   border: 'border-green-400' },
  'infrastructure-agent': { bg: 'bg-purple-100',  text: 'text-purple-800',  border: 'border-purple-400' },
  'qe-agent':             { bg: 'bg-orange-100',  text: 'text-orange-800',  border: 'border-orange-400' },
  'security-agent':       { bg: 'bg-red-100',     text: 'text-red-800',     border: 'border-red-400' },
  'docs-agent':           { bg: 'bg-teal-100',    text: 'text-teal-800',    border: 'border-teal-400' },
  'observability-agent':  { bg: 'bg-indigo-100',  text: 'text-indigo-800',  border: 'border-indigo-400' },
  'db-migration-agent':   { bg: 'bg-amber-100',   text: 'text-amber-800',   border: 'border-amber-400' },
  'performance-agent':    { bg: 'bg-cyan-100',    text: 'text-cyan-800',    border: 'border-cyan-400' },
};

export const FILE_STATUS_ICONS: Record<FileStatus, { icon: string; color: string }> = {
  unmodified: { icon: '',     color: '' },
  modified:   { icon: 'M',   color: 'text-yellow-600' },
  created:    { icon: 'A',   color: 'text-green-600' },
  deleted:    { icon: 'D',   color: 'text-red-600' },
  conflict:   { icon: 'C',   color: 'text-red-600 font-bold' },
};
```

### 4.4 Custom Tree Node Renderer

```tsx
// blocks/file-tree/FileTreeNodeRenderer.tsx
import React from 'react';
import { NodeRendererProps } from 'react-arborist';
import { AGENT_ROLE_COLORS, FILE_STATUS_ICONS } from '../../constants/agent-colors';
import type { FileTreeNode } from '../../atoms/file-tree-atoms';

export const FileTreeNodeRenderer = React.memo(function FileTreeNodeRenderer({
  node,
  style,
  dragHandle,
}: NodeRendererProps<FileTreeNode>) {
  const data = node.data;
  const ownerColor = data.ownerAgentRole
    ? AGENT_ROLE_COLORS[data.ownerAgentRole]
    : null;
  const statusIcon = FILE_STATUS_ICONS[data.fileStatus];
  const isActivelyModified = !!data.modifyingAgentId;

  return (
    <div
      ref={dragHandle}
      style={style}
      className={`flex items-center gap-1 px-2 py-0.5 cursor-pointer
        ${node.isSelected ? 'bg-blue-100' : 'hover:bg-gray-100'}
        ${isActivelyModified ? 'animate-pulse-subtle' : ''}`}
      onClick={() => node.isInternal ? node.toggle() : node.select()}
    >
      {/* Expand/collapse chevron for directories */}
      {node.isInternal ? (
        <span className="w-4 text-center text-gray-400 text-xs">
          {node.isOpen ? '\u25BE' : '\u25B8'}
        </span>
      ) : (
        <span className="w-4" />
      )}

      {/* File/folder icon */}
      <span className="w-4 text-center text-xs">
        {node.isInternal ? '\uD83D\uDCC1' : '\uD83D\uDCC4'}
      </span>

      {/* File name */}
      <span className={`flex-1 text-sm truncate ${
        data.fileStatus === 'deleted' ? 'line-through text-gray-400' : ''
      }`}>
        {data.name}
      </span>

      {/* File status indicator (M, A, D, C) */}
      {statusIcon.icon && (
        <span className={`text-xs font-mono ${statusIcon.color}`}>
          {statusIcon.icon}
        </span>
      )}

      {/* Active modification indicator (pulsing dot) */}
      {isActivelyModified && (
        <span className="w-2 h-2 rounded-full bg-blue-500 animate-pulse" />
      )}

      {/* Agent ownership badge */}
      {ownerColor && node.isInternal && (
        <span className={`text-xs px-1 py-0 rounded ${ownerColor.bg} ${ownerColor.text}`}>
          {data.ownerAgentRole!.replace('-agent', '')}
        </span>
      )}

      {/* Git status dot */}
      {data.gitStatus === 'staged' && (
        <span className="w-1.5 h-1.5 rounded-full bg-green-500" title="Staged" />
      )}
      {data.gitStatus === 'unstaged' && (
        <span className="w-1.5 h-1.5 rounded-full bg-yellow-500" title="Unstaged" />
      )}
      {data.gitStatus === 'untracked' && (
        <span className="w-1.5 h-1.5 rounded-full bg-gray-400" title="Untracked" />
      )}
    </div>
  );
});
```

### 4.5 File Tree Block Component

```tsx
// blocks/file-tree/FileTreeBlock.tsx
import React, { useCallback, useMemo } from 'react';
import { Tree } from 'react-arborist';
import { useAtom, useAtomValue } from 'jotai';
import { useOrchestratorStore } from '../../stores/orchestrator-store';
import { FileTreeNodeRenderer } from './FileTreeNodeRenderer';
import type { FileTreeNode, FilterMode } from '../../atoms/file-tree-atoms';

export const FileTreeBlock = React.memo(function FileTreeBlock({
  atoms,
  config,
}: {
  atoms: ReturnType<typeof createFileTreeAtoms>;
  config: BlockConfig;
}) {
  const treeData = useAtomValue(atoms.treeDataAtom);
  const [filterMode, setFilterMode] = useAtom(atoms.filterModeAtom);
  const [filterAgent, setFilterAgent] = useAtom(atoms.filterAgentAtom);
  const [searchQuery, setSearchQuery] = useAtom(atoms.searchQueryAtom);
  const activeAgentFiles = useAtomValue(atoms.activeAgentFilesAtom);

  const agents = useOrchestratorStore(s => s.agents);

  // Apply filters to tree data
  const filteredTree = useMemo(() => {
    let data = treeData;

    if (filterMode === 'modified_only') {
      data = filterTreeByPredicate(data, node =>
        node.fileStatus !== 'unmodified'
      );
    } else if (filterMode === 'by_agent' && filterAgent) {
      data = filterTreeByPredicate(data, node =>
        node.ownerAgentRole === filterAgent ||
        node.modifyingAgentId === filterAgent
      );
    }

    if (searchQuery) {
      data = filterTreeByPredicate(data, node =>
        node.name.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    return data;
  }, [treeData, filterMode, filterAgent, searchQuery]);

  // Cross-block communication: file click opens diff viewer
  const handleFileSelect = useCallback((nodes: FileTreeNode[]) => {
    if (nodes.length === 0) return;
    const node = nodes[0];
    if (node.isDirectory) return;

    // Update Zustand store, which diff-viewer block subscribes to
    useOrchestratorStore.getState().openFileInDiffViewer(
      node.modifyingAgentId ?? node.ownerAgentRole ?? '',
      node.id // full file path
    );
  }, []);

  return (
    <div className="file-tree-block flex flex-col h-full">
      {/* Toolbar */}
      <div className="flex items-center gap-2 px-3 py-2 border-b bg-gray-50">
        {/* Search */}
        <input
          type="text"
          placeholder="Search files..."
          value={searchQuery}
          onChange={e => setSearchQuery(e.target.value)}
          className="text-sm border rounded px-2 py-1 flex-1 min-w-0"
        />

        {/* Filter mode */}
        <select
          value={filterMode}
          onChange={e => setFilterMode(e.target.value as FilterMode)}
          className="text-xs border rounded px-1 py-1"
        >
          <option value="all">All files</option>
          <option value="modified_only">Modified only</option>
          <option value="by_agent">By agent</option>
        </select>

        {/* Agent filter (visible when filter mode is by_agent) */}
        {filterMode === 'by_agent' && (
          <select
            value={filterAgent ?? ''}
            onChange={e => setFilterAgent(e.target.value || null)}
            className="text-xs border rounded px-1 py-1"
          >
            <option value="">All agents</option>
            {agents.map(a => (
              <option key={a.id} value={a.id}>{a.role}</option>
            ))}
          </select>
        )}

        {/* Active modification count */}
        <span className="text-xs text-gray-500">
          {activeAgentFiles.size} active
        </span>
      </div>

      {/* Tree */}
      <div className="flex-1 min-h-0">
        <Tree<FileTreeNode>
          data={filteredTree}
          openByDefault={false}
          width="100%"
          height={600}
          indent={16}
          rowHeight={24}
          overscanCount={20}
          onSelect={handleFileSelect}
        >
          {FileTreeNodeRenderer}
        </Tree>
      </div>
    </div>
  );
});

/**
 * Recursively filter tree, keeping directories that contain matching descendants.
 */
function filterTreeByPredicate(
  nodes: FileTreeNode[],
  predicate: (node: FileTreeNode) => boolean
): FileTreeNode[] {
  return nodes
    .map(node => {
      if (node.isDirectory && node.children) {
        const filteredChildren = filterTreeByPredicate(node.children, predicate);
        if (filteredChildren.length > 0) {
          return { ...node, children: filteredChildren };
        }
        return null;
      }
      return predicate(node) ? node : null;
    })
    .filter((n): n is FileTreeNode => n !== null);
}
```

---

## 5. Cross-Block Communication

The three blocks in this phase must communicate. The pattern uses Zustand actions as the shared bus, with each block subscribing to the relevant slice of global state.

### 5.1 Zustand Store Extensions

```typescript
// stores/orchestrator-store.ts (additions for Phase 5)

interface CodeReviewSlice {
  // Cross-block coordination state
  diffViewerSelectedFile: string | null;    // fileId currently shown
  diffViewerSelectedAgent: string | null;

  // Actions
  openFileInDiffViewer: (agentId: string, filePath: string) => void;
  openViolationInDiffViewer: (violation: ContractViolation) => void;
}

// Add to existing store
const codeReviewSlice: StateCreator<CodeReviewSlice> = (set) => ({
  diffViewerSelectedFile: null,
  diffViewerSelectedAgent: null,

  openFileInDiffViewer: (agentId, filePath) => {
    const fileId = `${agentId}:${filePath}`;
    set({
      diffViewerSelectedFile: fileId,
      diffViewerSelectedAgent: agentId,
      // Also switch the active layout panel to include diff viewer
      activePanelId: 'diff-viewer',
    });
  },

  openViolationInDiffViewer: (violation) => {
    if (violation.filePath) {
      const fileId = `${violation.agentId}:${violation.filePath}`;
      set({
        diffViewerSelectedFile: fileId,
        diffViewerSelectedAgent: violation.agentId,
        activePanelId: 'diff-viewer',
      });
    }
  },
});
```

### 5.2 Communication Flow Diagram

```
File Tree Block                    Zustand Store                    Diff Viewer Block
     |                                  |                                  |
     |  user clicks file                |                                  |
     |  ------>  openFileInDiffViewer()  |                                  |
     |                                  |  set diffViewerSelectedFile      |
     |                                  |  -------->  selector triggers    |
     |                                  |             useEffect swaps      |
     |                                  |             Monaco models        |
     |                                  |                                  |

Contract Compliance Block          Zustand Store                    Diff Viewer Block
     |                                  |                                  |
     |  user clicks "View diff"         |                                  |
     |  ------>  openViolationInDiffViewer()                               |
     |                                  |  set diffViewerSelectedFile      |
     |                                  |  set activePanelId               |
     |                                  |  -------->  selector triggers    |
     |                                  |             panel focuses        |
     |                                  |             Monaco models swap   |
     |                                  |                                  |
```

### 5.3 Connecting the Diff Viewer to Zustand

```typescript
// Inside DiffViewerBlock -- subscribe to cross-block file selection
const zustandSelectedFile = useOrchestratorStore(
  s => s.diffViewerSelectedFile,
  (a, b) => a === b // Shallow equality prevents re-render on unrelated store changes
);

useEffect(() => {
  if (zustandSelectedFile && zustandSelectedFile !== selectedFile) {
    setSelectedFile(zustandSelectedFile);
  }
}, [zustandSelectedFile, selectedFile, setSelectedFile]);
```

---

## 6. Block Registration

```typescript
// blocks/registry-phase5.ts
import { BlockRegistry } from '../core/block-registry';
import { createDiffViewerAtoms } from '../atoms/diff-viewer-atoms';
import { createContractComplianceAtoms } from '../atoms/contract-compliance-atoms';
import { createFileTreeAtoms } from '../atoms/file-tree-atoms';
import { DiffViewerBlock } from './diff-viewer/DiffViewerBlock';
import { ContractComplianceBlock } from './contract-compliance/ContractComplianceBlock';
import { FileTreeBlock } from './file-tree/FileTreeBlock';
import { modelCache } from '../models/monaco-model-cache';

export function registerPhase5Blocks() {
  BlockRegistry.set('diff-viewer', {
    type: 'diff-viewer',
    displayName: 'Code Changes',
    icon: 'code-compare',
    createAtoms: createDiffViewerAtoms,
    Component: DiffViewerBlock,
    dispose: () => {
      // Critical: dispose all Monaco models to free memory
      modelCache.disposeAll();
    },
  });

  BlockRegistry.set('contract-compliance', {
    type: 'contract-compliance',
    displayName: 'Contract Status',
    icon: 'shield-check',
    createAtoms: createContractComplianceAtoms,
    Component: ContractComplianceBlock,
  });

  BlockRegistry.set('file-tree', {
    type: 'file-tree',
    displayName: 'File Explorer',
    icon: 'folder-tree',
    createAtoms: createFileTreeAtoms,
    Component: FileTreeBlock,
  });
}
```

---

## 7. Review Layout Preset

Phase 5 introduces a dedicated "Review" layout optimized for code review workflows:

```typescript
// layouts/review-layout.ts
export const REVIEW_LAYOUT: DashboardLayout = {
  id: 'review',
  name: 'Review',
  panels: [
    {
      id: 'file-tree-panel',
      blockType: 'file-tree',
      blockConfig: {},
      size: 15,           // 15% width
      minSize: 10,
      collapsible: true,
    },
    {
      id: 'diff-viewer-panel',
      blockType: 'diff-viewer',
      blockConfig: {},
      size: 60,           // 60% width
      minSize: 30,
    },
    {
      id: 'compliance-panel',
      blockType: 'contract-compliance',
      blockConfig: {},
      size: 25,           // 25% width
      minSize: 15,
      collapsible: true,
    },
  ],
  savedAt: new Date(),
};
```

---

## 8. Event Integration

### 8.1 AG-UI Events Consumed

| Event | Handler | Updates |
|-------|---------|---------|
| `TOOL_CALL_RESULT` (file_write) | Parse file path, original/modified content | file-tree atoms, model cache |
| `STATE_DELTA` (agent status) | Update modifying agent indicator | file-tree `activeAgentFilesAtom` |
| `RAW` (qa-report) | Extract scores, violations, endpoint compliance | contract-compliance atoms |
| `RAW` (change_group) | Group file changes by purpose | diff-viewer `changeGroupsAtom` |
| `TEXT_MESSAGE_CONTENT` (code streaming) | Throttled append to Monaco model | diff-viewer via `streamingDiff` |
| `STATE_SNAPSHOT` (5-second refresh) | Full reconciliation of all block state | All three blocks |

### 8.2 Event Routing

```typescript
// services/event-router-phase5.ts

function routePhase5Events(event: OrchestratorEvent): void {
  switch (event.type) {
    case 'TOOL_CALL_RESULT':
      if (event.toolName === 'file_write' || event.toolName === 'file_edit') {
        handleFileChangeEvent(event);
      }
      break;

    case 'RAW':
      if (event.payload?.type === 'qa-report') {
        handleQAReportEvent(event);
      } else if (event.payload?.type === 'change_group') {
        handleChangeGroupEvent(event);
      }
      break;

    case 'STATE_DELTA':
      handleAgentStatusEvent(event);
      break;

    case 'TEXT_MESSAGE_CONTENT':
      if (event.metadata?.isCodeOutput) {
        handleCodeStreamingEvent(event);
      }
      break;
  }
}

function handleFileChangeEvent(event: OrchestratorEvent): void {
  const { filePath, originalContent, modifiedContent } = event.result;
  const fileId = `${event.agentId}:${filePath}`;

  // Update model cache for diff viewer
  modelCache.getOrCreate(fileId, originalContent, modifiedContent, filePath);

  // Update file tree active modifications
  const activeFiles = fileTreeAtoms.activeAgentFilesAtom;
  // ... atom update logic
}

function handleQAReportEvent(event: OrchestratorEvent): void {
  const report = event.payload.payload;

  // Extract scores
  const scores: ComplianceScores = {
    contract_conformance: report.contract_conformance,
    security: report.security,
    performance: report.performance,
    overall: (report.contract_conformance + report.security + report.performance) / 3,
  };

  // Extract violations
  const violations: ContractViolation[] = (report.violations ?? []).map(
    (v: any) => ({
      id: v.id,
      severity: v.severity,
      category: v.category,
      message: v.message,
      endpointId: v.endpoint_id,
      filePath: v.file_path,
      agentId: event.agentId,
      agentRole: event.agentRole,
      suggestion: v.suggestion,
      autoFixable: v.auto_fixable ?? false,
    })
  );

  // Update contract-compliance atoms
  // ... atom update logic
}
```

---

## 9. Performance Considerations

### 9.1 Monaco Model Caching

| Concern | Strategy |
|---------|----------|
| Memory per model | ~50-200KB depending on file size. 100 models = 5-20MB. |
| LRU eviction | Evict at 100 models. Disposed models free ITextModel memory. |
| Model swap cost | `editor.setModel()` is <1ms. No DOM changes needed. |
| Language detection | Sync, O(1) hash lookup on file extension. |

### 9.2 Tree Virtualization

react-arborist virtualizes the tree rendering. Only visible nodes are in the DOM.

| Metric | Target |
|--------|--------|
| Total nodes | 10,000+ supported |
| Visible nodes | ~30-50 at a time (depends on panel height) |
| DOM elements | ~50-100 (visible + overscan buffer of 20) |
| Expand/collapse | <10ms (no full tree re-render) |

### 9.3 Streaming Code Throttle

The 100ms throttle window for streaming code balances responsiveness with performance. At typical LLM output speeds (50-100 tokens/sec), this produces 5-10 buffer flushes per second, which is smooth visually without overwhelming Monaco's change tracking.

---

## 10. Testing Strategy

### 10.1 Unit Tests

```typescript
// __tests__/monaco-model-cache.test.ts
describe('MonacoModelCache', () => {
  it('creates and caches model pairs', () => {
    const pair = modelCache.getOrCreate('test:file.ts', 'old', 'new', 'file.ts');
    expect(pair.language).toBe('typescript');
    expect(pair.original.getValue()).toBe('old');
    expect(pair.modified.getValue()).toBe('new');

    // Second call returns cached pair
    const pair2 = modelCache.getOrCreate('test:file.ts', 'old', 'new', 'file.ts');
    expect(pair2).toBe(pair);
  });

  it('evicts LRU models at capacity', () => {
    for (let i = 0; i < 101; i++) {
      modelCache.getOrCreate(`test:file${i}.ts`, '', '', `file${i}.ts`);
    }
    // First model should have been evicted
    // (implementation detail: verify via cache size or by checking model disposal)
  });

  it('appends content without recreating model', () => {
    modelCache.getOrCreate('test:stream.ts', '', '', 'stream.ts');
    modelCache.appendModified('test:stream.ts', 'line1\n');
    modelCache.appendModified('test:stream.ts', 'line2\n');

    const pair = modelCache.getOrCreate('test:stream.ts', '', '', 'stream.ts');
    expect(pair.modified.getValue()).toBe('line1\nline2\n');
  });

  it('detects language from file extension', () => {
    const cases = [
      ['file.py', 'python'],
      ['file.rs', 'rust'],
      ['file.tsx', 'typescript'],
      ['file.unknown', 'plaintext'],
    ];
    for (const [path, expected] of cases) {
      const pair = modelCache.getOrCreate(`test:${path}`, '', '', path);
      expect(pair.language).toBe(expected);
      modelCache.dispose(`test:${path}`);
    }
  });
});

// __tests__/contract-matcher.test.ts
describe('matchEndpoints', () => {
  it('matches endpoints by method and normalized path', () => {
    const contract = [
      { method: 'GET', path: '/api/users/{id}', operationId: 'getUser', responses: { '200': {} } },
    ];
    const impl = [
      { method: 'get', path: '/api/users/:id', filePath: 'routes/users.ts', agentId: 'be', agentRole: 'backend-agent', statusCodes: [200], requestSchema: undefined, responseSchema: undefined },
    ];

    const result = matchEndpoints(contract, impl);
    expect(result).toHaveLength(1);
    expect(result[0].overallStatus).not.toBe('not_implemented');
  });

  it('marks unimplemented endpoints', () => {
    const contract = [
      { method: 'DELETE', path: '/api/users/{id}', operationId: 'deleteUser', responses: { '200': {} } },
    ];
    const impl: any[] = [];

    const result = matchEndpoints(contract, impl);
    expect(result[0].overallStatus).toBe('not_implemented');
  });
});

// __tests__/change-grouper.test.ts
describe('groupChanges', () => {
  it('groups changes with explicit groupId', () => {
    const changes = [
      { agentId: 'be', agentRole: 'backend-agent', filePath: 'a.ts', changeType: 'modified', originalContent: '', modifiedContent: '', purpose: 'Add auth', groupId: 'g1', timestamp: 1000 },
      { agentId: 'be', agentRole: 'backend-agent', filePath: 'b.ts', changeType: 'created', originalContent: '', modifiedContent: '', purpose: 'Add auth', groupId: 'g1', timestamp: 1001 },
    ];

    const groups = groupChanges(changes as any);
    expect(groups).toHaveLength(1);
    expect(groups[0].files).toHaveLength(2);
    expect(groups[0].purpose).toBe('Add auth');
  });

  it('falls back to temporal grouping', () => {
    const changes = [
      { agentId: 'be', agentRole: 'backend-agent', filePath: 'a.ts', changeType: 'modified', originalContent: '', modifiedContent: '', timestamp: 1000 },
      { agentId: 'be', agentRole: 'backend-agent', filePath: 'b.ts', changeType: 'modified', originalContent: '', modifiedContent: '', timestamp: 1010 },
      { agentId: 'be', agentRole: 'backend-agent', filePath: 'c.ts', changeType: 'modified', originalContent: '', modifiedContent: '', timestamp: 60000 },
    ];

    const groups = groupChanges(changes as any);
    expect(groups).toHaveLength(2); // First two within 30s, third separate
  });
});
```

### 10.2 Integration Tests

```typescript
// __tests__/integration/cross-block-communication.test.tsx
describe('Cross-block communication', () => {
  it('clicking file in tree opens it in diff viewer', async () => {
    const { getByText } = render(
      <TestDashboard layout="review">
        <FileTreeBlock atoms={fileTreeAtoms} config={{}} />
        <DiffViewerBlock atoms={diffViewerAtoms} config={{}} />
      </TestDashboard>
    );

    // Simulate file tree click
    fireEvent.click(getByText('auth-middleware.ts'));

    // Verify Zustand state updated
    expect(useOrchestratorStore.getState().diffViewerSelectedFile)
      .toBe('backend-agent:src/middleware/auth-middleware.ts');

    // Verify diff viewer responded (Monaco model swap)
    await waitFor(() => {
      expect(screen.getByTestId('diff-viewer-filename'))
        .toHaveTextContent('auth-middleware.ts');
    });
  });

  it('clicking violation in compliance navigates to diff', async () => {
    // Set up compliance block with a violation that has a file path
    const violation: ContractViolation = {
      id: 'v1',
      severity: 'HIGH',
      category: 'schema',
      message: 'Missing required field: email',
      filePath: 'src/routes/users.ts',
      agentId: 'backend-agent-1',
      agentRole: 'backend-agent',
      autoFixable: false,
    };

    // Render compliance block
    const { getByText } = render(
      <TestDashboard layout="review">
        <ContractComplianceBlock atoms={complianceAtoms} config={{}} />
      </TestDashboard>
    );

    // Inject violation data
    // ... set atom values

    // Click "View diff" link
    fireEvent.click(getByText('View diff'));

    // Verify navigation
    expect(useOrchestratorStore.getState().diffViewerSelectedFile)
      .toBe('backend-agent-1:src/routes/users.ts');
  });
});
```

### 10.3 E2E Tests (Playwright)

```typescript
// e2e/code-review-workflow.spec.ts
test.describe('Code Review Workflow', () => {
  test('full review cycle: tree -> diff -> compliance', async ({ page }) => {
    await page.goto('/dashboard?layout=review');

    // Wait for blocks to render
    await expect(page.locator('[data-block="file-tree"]')).toBeVisible();
    await expect(page.locator('[data-block="diff-viewer"]')).toBeVisible();
    await expect(page.locator('[data-block="contract-compliance"]')).toBeVisible();

    // Click a modified file in the tree
    await page.click('[data-file="src/routes/users.ts"]');

    // Verify diff viewer shows the file
    await expect(page.locator('.diff-viewer-block')).toContainText('users.ts');

    // Verify Monaco editor is rendering diffs (check for diff decorations)
    await expect(page.locator('.monaco-diff-editor')).toBeVisible();

    // Toggle diff mode
    await page.click('button:has-text("Unified")');
    await expect(page.locator('.monaco-diff-editor')).toHaveClass(/inline/);

    // Accept the change
    await page.click('button:has-text("Accept")');
    await expect(page.locator('button:has-text("Accept")')).toHaveClass(/bg-green-600/);

    // Check contract compliance panel shows scores
    await expect(page.locator('.score-header')).toContainText('Contract:');
  });

  test('single Monaco editor instance constraint', async ({ page }) => {
    await page.goto('/dashboard?layout=review');

    // Count Monaco editor instances in the DOM
    const editorCount = await page.locator('.monaco-diff-editor').count();
    expect(editorCount).toBe(1);

    // Select different files -- should still be 1 editor
    await page.click('[data-file="src/routes/users.ts"]');
    await page.click('[data-file="src/routes/posts.ts"]');
    await page.click('[data-file="src/models/user.ts"]');

    const editorCountAfter = await page.locator('.monaco-diff-editor').count();
    expect(editorCountAfter).toBe(1);
  });
});
```

---

## 11. Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| AC-1 | Diff viewer shows before/after code changes from an agent | Integration test: load file change event, verify both panels render |
| AC-2 | Only ONE Monaco DiffEditor instance exists at any time | E2E test: select 5 different files, assert `.monaco-diff-editor` count === 1 |
| AC-3 | File selector switches models without creating new editors | Unit test: verify `editor.setModel()` called, not `new DiffEditor()` |
| AC-4 | Side-by-side and unified diff modes toggle without re-mount | Unit test: verify `updateOptions` called, component not unmounted |
| AC-5 | Streaming code output appears in diff viewer in real-time | Integration test: emit code chunks, verify model content updates |
| AC-6 | Agent changes are grouped by purpose (Devin pattern) | Unit test: explicit groups and temporal fallback grouping |
| AC-7 | Contract compliance shows endpoint-by-endpoint comparison | Integration test: load QA report, verify endpoint table renders |
| AC-8 | Violations are color-coded by severity | Visual regression test: screenshot comparison with known violations |
| AC-9 | Expandable rows show schema diff details | Integration test: click row, verify diff details render |
| AC-10 | File tree shows real-time agent modification indicators | Integration test: emit agent file write event, verify pulsing indicator |
| AC-11 | File tree nodes are color-coded by owning agent role | Visual test: verify 9 distinct colors for 9 agent roles |
| AC-12 | Clicking a file in tree opens it in diff viewer | Cross-block integration test |
| AC-13 | Clicking "View diff" on a violation navigates to diff viewer | Cross-block integration test |
| AC-14 | All three blocks work in the "Review" layout preset | E2E test: load review layout, verify all three blocks visible |
| AC-15 | File tree supports 10,000+ nodes without jank | Performance test: generate 10K node tree, measure scroll FPS |
| AC-16 | Accept/reject per-file decisions are tracked | Unit test: verify decision state atom updates correctly |
| AC-17 | Monaco model cache respects 100-model LRU limit | Unit test: create 101 models, verify first is disposed |
| AC-18 | Language auto-detection works for 30+ file extensions | Unit test: verify extension map coverage |

---

## 12. Risk Considerations

| Risk | Severity | Probability | Mitigation |
|------|----------|------------|------------|
| Monaco editor global state corruption from model swaps | High | Low | Extensive unit tests on model lifecycle. `dispose()` on block teardown. |
| Monaco DiffEditor memory leak from undisposed models | High | Medium | LRU eviction in model cache. `disposeAll()` on build completion. |
| react-arborist performance at 10K+ nodes | Medium | Low | Virtualized rendering is core to the library. Set `overscanCount` to 20. |
| Cross-block Zustand selector causes cascading re-renders | Medium | Medium | Use strict equality selectors. Profile with React DevTools. |
| Streaming code chunks arrive out of order | Low | Low | Sequence number in events. Buffer and reorder before applying. |
| OpenAPI schema parsing fails on complex schemas | Medium | Medium | Use established parser (swagger-parser). Graceful degradation: show raw JSON diff. |
| Agent change groups arrive after file changes | Low | Medium | Buffer file changes for 5s before falling back to temporal grouping. |

---

## 13. Dependencies

### NPM Packages (New in Phase 5)

| Package | Version | Purpose | Size |
|---------|---------|---------|------|
| `@monaco-editor/react` | latest | DiffEditor component | ~50KB (Monaco itself is ~5MB, loaded async) |
| `react-arborist` | latest | Virtualized file tree | ~40KB |
| `ajv` | 8.x | JSON Schema validation for contract compliance | ~120KB |
| `swagger-parser` | 10.x | OpenAPI spec parsing | ~80KB |

### Phase 2 Dependencies

- Block registry system (core infrastructure)
- `react-resizable-panels` layout system
- Zustand store foundation
- Jotai atom creation pattern

### Phase 3 Dependencies (Soft)

- AG-UI event adapter (for receiving file change and QA report events)
- SSE streaming infrastructure (for real-time updates)

Phase 5 can begin development with mock event data before Phase 3 is complete.

---

## 14. Implementation Order

| Week | Day 1-2 | Day 3-4 | Day 5 |
|------|---------|---------|-------|
| **Week 1** | Monaco model cache + single instance DiffEditor | File tree with react-arborist + custom node renderer | Cross-block communication (Zustand wiring) |
| **Week 2** | Contract compliance data model + endpoint matcher | Streaming code integration + change grouping | Integration testing + E2E tests + Review layout |
