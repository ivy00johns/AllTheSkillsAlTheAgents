import { useState } from "react";

const C = {
  bg:        "#08080e",
  surface:   "#10101a",
  surface2:  "#16162a",
  border:    "#22223a",
  borderHi:  "#333355",
  text:      "#ddddf0",
  textDim:   "#6666a0",
  textFaint: "#333355",
  // Per-framework brand colors
  oc:  "#f7a06e",   // OpenClaw  — amber/orange
  gt:  "#7c6af7",   // Gastown   — violet
  bd:  "#4ecdc4",   // Beads     — teal
  // Semantic
  gap:    "#f76e6e",
  bridge: "#6ef7a0",
  warn:   "#f7c04a",
};

const TABS = [
  { id: "what",        label: "What Each Does" },
  { id: "layers",      label: "Layer Breakdown" },
  { id: "connections", label: "How They Connect" },
  { id: "flow",        label: "End-to-End Flow" },
  { id: "gaps",        label: "Gaps Between Them" },
];

/* ─── helpers ─── */
function Tag({ color, children, small }) {
  return (
    <span style={{
      display: "inline-block",
      background: color + "1a",
      border: `1px solid ${color}44`,
      borderRadius: 4,
      padding: small ? "1px 6px" : "2px 8px",
      color: color,
      fontSize: small ? 9 : 10,
      fontFamily: "monospace",
      letterSpacing: 0.5,
      whiteSpace: "nowrap",
    }}>{children}</span>
  );
}

function Card({ color, title, sub, children, style = {} }) {
  return (
    <div style={{
      background: C.surface,
      border: `1px solid ${color}33`,
      borderLeft: `3px solid ${color}`,
      borderRadius: 8,
      padding: "14px 16px",
      ...style,
    }}>
      {title && <div style={{ color, fontSize: 13, fontWeight: 700, marginBottom: sub ? 2 : 8 }}>{title}</div>}
      {sub   && <div style={{ color: C.textDim, fontSize: 11, marginBottom: 8 }}>{sub}</div>}
      {children}
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════
   TAB 1 — WHAT EACH DOES
═══════════════════════════════════════════════════════════ */
function WhatEachDoes() {
  const [active, setActive] = useState(null);

  const fws = [
    {
      id: "oc", color: C.oc,
      name: "OpenClaw",
      tagline: "The always-on autonomous agent daemon",
      origin: "Peter Steinberger (PSPDFKit founder) · Jan 2026 · 310K+ stars",
      oneliner: "A persistent background process that connects your AI agent to every messaging platform you use — WhatsApp, Telegram, Discord, Slack, Signal, iMessage — and lets it act proactively on your behalf.",
      what: "OpenClaw is the interface and runtime layer. It is NOT an orchestrator. It's the daemon that keeps an AI agent alive 24/7, gives it a messaging identity, connects it to tools, and lets it reach out proactively via a heartbeat scheduler.",
      layers: ["Interface (12+ messaging adapters)", "Agent Runtime (ReAct loop)", "Tool/Skill Registry (ClawHub, SKILL.md)", "3-tier Memory (session/daily/long-term)"],
      notThis: ["An orchestrator for coding tasks", "A multi-agent fleet manager", "A quality enforcement system"],
      architecture: [
        { label: "Gateway",          desc: "WebSocket control plane on :18789. Single Node.js process." },
        { label: "Channel Adapters", desc: "Baileys (WhatsApp), grammY (Telegram), Discord, Slack, Signal, iMessage, IRC, Teams, Matrix, LINE." },
        { label: "Session Manager",  desc: "Resolves sender identity. DMs = main session. Groups = own session." },
        { label: "Command Queue",    desc: "Serializes tool calls per session lane — prevents state corruption." },
        { label: "Agent Runtime",    desc: "Assembles context (AGENTS.md + SOUL.md + TOOLS.md + MEMORY.md) → ReAct loop." },
        { label: "SKILL.md System",  desc: "5400+ community skills on ClawHub. ~24 tokens injected per skill at boot; full content on demand." },
        { label: "Sub-Agents",       desc: "Depth-0 spawns Depth-1 (orchestrators) → Depth-2 (leaf workers). Results flow up via announce chain." },
        { label: "Memory",           desc: "Session JSONL + daily .md logs + curated MEMORY.md + sqlite-vec for embeddings." },
      ],
      superpower: "Only framework with true proactive behavior — a heartbeat scheduler lets the agent reach out to you, not just respond.",
      gotcha: "26% CVE rate on ClawHub skills. CVE-2026-25253 enabled RCE on 21K+ exposed instances. Single-process = no horizontal scaling.",
    },
    {
      id: "gt", color: C.gt,
      name: "Gastown",
      tagline: "Kubernetes for AI coding agents",
      origin: "Steve Yegge (Amazon/Google/Sourcegraph) · Jan 2026 · 12.4K stars · Go",
      oneliner: "A multi-agent workspace manager that runs 20–30 parallel AI coding sessions simultaneously — each in an isolated git worktree — coordinated by a Mayor agent and tracked with a Dolt-backed mail system.",
      what: "Gastown is the orchestration and fleet management layer for coding work. It doesn't replace your coding tool (Claude Code, Codex, Cursor) — it manages many of them in parallel. The human tells the Mayor what to build; the Mayor coordinates everything else.",
      layers: ["Orchestration (Mayor/MEOW dispatch)", "Fleet Management (Polecats, Witness, Refinery)", "Git Worktree Isolation", "Inter-Agent Mail (Dolt-backed)"],
      notThis: ["A messaging interface layer", "A quality enforcement system", "A general-purpose agent memory system"],
      architecture: [
        { label: "Mayor",     desc: "The human-facing Claude Code instance. Receives goals, decomposes into beads, dispatches convoys, synthesizes results. Never writes code." },
        { label: "MEOW",      desc: "Mayor-Enhanced Orchestration Workflow. The dispatch protocol: Mayor → beads → convoy → Polecats." },
        { label: "Polecats",  desc: "Ephemeral grunt workers. Each lives in its own git worktree. Spawned per task, killed on completion." },
        { label: "Witness",   desc: "Per-rig lifecycle manager. Detects stuck Polecats. Includes spawn circuit breaker (MaxBeadRespawns)." },
        { label: "Refinery",  desc: "Merge queue processor. Handles conflicts when late-finishing agents find main has moved." },
        { label: "Deacon",    desc: "Background supervisor daemon for the whole Town. Health patrol." },
        { label: "Mail",      desc: "gt mail send/inbox/read — Dolt-backed messaging between agents. Plus nudges for real-time alerts." },
        { label: "GUPP",      desc: "Gas Town Universal Propulsion Principle: if there's work on your hook, run it. Enables context-window handoff via séance protocol." },
      ],
      superpower: "Built-in A/B testing for models: every task has completion time, quality, and revision count attributed to the specific agent that ran it.",
      gotcha: "Requires 3+ Claude Pro Max plans (~$600/month+). Estimated $100/hr burn rate during active use. Auto-merges even with failing CI. Local-only, no team collaboration.",
    },
    {
      id: "bd", color: C.bd,
      name: "Beads",
      tagline: "Git-native task memory for coding agents",
      origin: "Steve Yegge · Jan 2026 · 18.1K stars · Go (+ Rust 'br')",
      oneliner: "A distributed, git-backed graph issue tracker designed specifically for AI coding agents — solving the '50 First Dates' problem where agents wake each session with no memory of prior work.",
      what: "Beads is the persistent memory and work-tracking layer. It is NOT an orchestrator, NOT a runtime, and NOT an interface. It's a purpose-built database that agents read and write to coordinate work across sessions and across agents — without coordination overhead.",
      layers: ["Task Graph (hash-based IDs, dependency tracking)", "Git-native State (Dolt-backed in v0.50+)", "Token-efficient Context Injection (bd prime)", "Topological Sort Server-side"],
      notThis: ["An agent runtime", "An orchestrator or router", "An interface or messaging layer"],
      architecture: [
        { label: "bd create",    desc: "Creates a task with hash ID (e.g., bd-a1b2). Supports --deps for dependency chains, --priority, --type." },
        { label: "bd ready",     desc: "Returns only unblocked tasks, topologically sorted. Server computes the graph — agent just receives the list." },
        { label: "bd update --claim", desc: "Atomic claiming of a task. No two agents claim the same bead — coordination-free parallelism." },
        { label: "bd close",     desc: "Marks done, frees dependents. Triggers cascade: any bead waiting on this one becomes 'ready'." },
        { label: "bd prime",     desc: "Generates ~80 lines of dynamic workflow context (~1-2K tokens). The agent's task briefing." },
        { label: "Dolt backend", desc: "Version-controlled SQL DB with cell-level merge and native branching. Every write auto-commits. Push/pull for sync." },
        { label: "Hash IDs",     desc: "Content-addressed IDs prevent merge conflicts across agents and branches — no coordination needed." },
        { label: "JSONL legacy", desc: "Pre-v0.50: .beads/issues.jsonl as source of truth, SQLite for fast queries. Still supported." },
      ],
      superpower: "bd ready does topological sort server-side — agents never burn tokens analyzing dependency graphs. The tool thinks so the agent doesn't have to.",
      gotcha: "Performance degrades beyond ~500 issues. bd edit hangs agent processes (use bd update --flags instead). Agents in long sessions forget about Beads by hour two.",
    },
  ];

  return (
    <div style={{ padding: "28px 20px" }}>
      <h2 style={{ color: C.text, fontFamily: "'Georgia',serif", fontSize: 20, fontWeight: 400, marginBottom: 6 }}>
        What Each Framework Actually Does
      </h2>
      <p style={{ color: C.textDim, fontSize: 12, marginBottom: 24, lineHeight: 1.7 }}>
        These three repos are often mentioned together but they are <em style={{ color: C.text }}>completely different kinds of things</em>.
        Understanding this prevents the biggest architectural mistake: trying to replace one with another.
      </p>

      {/* Summary row */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12, marginBottom: 28 }}>
        {fws.map(fw => (
          <div key={fw.id} style={{
            background: C.surface2,
            border: `2px solid ${active === fw.id ? fw.color : fw.color + "33"}`,
            borderRadius: 10, padding: "14px 16px",
            cursor: "pointer",
            transition: "all 0.15s",
          }} onClick={() => setActive(active === fw.id ? null : fw.id)}>
            <div style={{ color: fw.color, fontSize: 16, fontWeight: 700, marginBottom: 4 }}>{fw.name}</div>
            <div style={{ color: C.textDim, fontSize: 11, lineHeight: 1.5, marginBottom: 10 }}>{fw.tagline}</div>
            <div style={{ color: C.text, fontSize: 11, lineHeight: 1.6, fontStyle: "italic" }}>"{fw.oneliner}"</div>
          </div>
        ))}
      </div>

      {/* Detail expansion */}
      {fws.map(fw => active === fw.id && (
        <div key={fw.id} style={{ marginBottom: 24 }}>
          {/* Origin bar */}
          <div style={{
            background: fw.color + "0e", border: `1px solid ${fw.color}22`,
            borderRadius: "8px 8px 0 0", padding: "8px 16px",
            color: fw.color + "99", fontSize: 10, fontFamily: "monospace",
          }}>{fw.origin}</div>

          <div style={{
            background: C.surface, border: `1px solid ${fw.color}33`,
            borderRadius: "0 0 8px 8px", padding: "16px",
          }}>
            {/* What it IS */}
            <div style={{ marginBottom: 16 }}>
              <div style={{ color: C.textDim, fontSize: 10, letterSpacing: 2, marginBottom: 8, textTransform: "uppercase" }}>What it is</div>
              <p style={{ color: C.text, fontSize: 13, lineHeight: 1.7, margin: 0 }}>{fw.what}</p>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 16 }}>
              {/* Layers it covers */}
              <div>
                <div style={{ color: C.textDim, fontSize: 10, letterSpacing: 2, marginBottom: 8, textTransform: "uppercase" }}>Layers it covers</div>
                {fw.layers.map(l => (
                  <div key={l} style={{ display: "flex", gap: 6, marginBottom: 5, alignItems: "flex-start" }}>
                    <span style={{ color: fw.color, marginTop: 2, fontSize: 10 }}>✓</span>
                    <span style={{ color: C.text, fontSize: 11 }}>{l}</span>
                  </div>
                ))}
              </div>
              {/* NOT this */}
              <div>
                <div style={{ color: C.textDim, fontSize: 10, letterSpacing: 2, marginBottom: 8, textTransform: "uppercase" }}>It is NOT</div>
                {fw.notThis.map(l => (
                  <div key={l} style={{ display: "flex", gap: 6, marginBottom: 5, alignItems: "flex-start" }}>
                    <span style={{ color: C.gap, marginTop: 2, fontSize: 10 }}>✗</span>
                    <span style={{ color: C.textDim, fontSize: 11 }}>{l}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Architecture components */}
            <div style={{ marginBottom: 16 }}>
              <div style={{ color: C.textDim, fontSize: 10, letterSpacing: 2, marginBottom: 10, textTransform: "uppercase" }}>Internal components</div>
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px,1fr))", gap: 8 }}>
                {fw.architecture.map(a => (
                  <div key={a.label} style={{
                    background: C.surface2, borderRadius: 6,
                    border: `1px solid ${C.border}`, padding: "8px 10px",
                  }}>
                    <div style={{ color: fw.color, fontSize: 11, fontFamily: "monospace", marginBottom: 3 }}>{a.label}</div>
                    <div style={{ color: C.textDim, fontSize: 10, lineHeight: 1.5 }}>{a.desc}</div>
                  </div>
                ))}
              </div>
            </div>

            {/* Superpower + Gotcha */}
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
              <div style={{ background: fw.color + "0d", border: `1px solid ${fw.color}22`, borderRadius: 6, padding: "10px 12px" }}>
                <div style={{ color: fw.color, fontSize: 10, letterSpacing: 1, marginBottom: 5, textTransform: "uppercase" }}>⚡ Superpower</div>
                <div style={{ color: fw.color + "cc", fontSize: 11, lineHeight: 1.5 }}>{fw.superpower}</div>
              </div>
              <div style={{ background: C.gap + "0d", border: `1px solid ${C.gap}22`, borderRadius: 6, padding: "10px 12px" }}>
                <div style={{ color: C.gap, fontSize: 10, letterSpacing: 1, marginBottom: 5, textTransform: "uppercase" }}>⚠ Gotcha</div>
                <div style={{ color: C.gap + "cc", fontSize: 11, lineHeight: 1.5 }}>{fw.gotcha}</div>
              </div>
            </div>
          </div>
        </div>
      ))}

      <div style={{
        background: C.surface2, border: `1px solid ${C.bridge}22`,
        borderRadius: 8, padding: "14px 18px",
      }}>
        <div style={{ color: C.bridge, fontSize: 11, fontWeight: 700, marginBottom: 6 }}>
          The Key Insight
        </div>
        <p style={{ color: C.textDim, fontSize: 12, lineHeight: 1.7, margin: 0 }}>
          <span style={{ color: C.oc }}>OpenClaw</span> is your agent's <strong style={{ color: C.text }}>face and voice</strong> — it handles how the world reaches the agent and how the agent reaches the world.{" "}
          <span style={{ color: C.gt }}>Gastown</span> is your agent's <strong style={{ color: C.text }}>hands</strong> — it manages the workforce that does the actual coding.{" "}
          <span style={{ color: C.bd }}>Beads</span> is your agent's <strong style={{ color: C.text }}>memory</strong> — it's the shared brain that lets multiple agents coordinate without stepping on each other.{" "}
          They are complementary layers, not alternatives.
        </p>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════
   TAB 2 — LAYER BREAKDOWN
═══════════════════════════════════════════════════════════ */
function LayerBreakdown() {
  const rows = [
    {
      layer: "Interface",
      desc: "How the world reaches the agent — and how the agent reaches the world",
      oc:  { level: "full",   notes: "12+ channel adapters. WhatsApp, Telegram, Discord, Slack, Signal, iMessage, IRC, Teams, Matrix, LINE. Heartbeat scheduler for proactive outreach." },
      gt:  { level: "none",   notes: "No interface layer. tmux terminal only. Assumes developer is watching panes." },
      bd:  { level: "none",   notes: "CLI only (bd commands). No messaging, no UI, no event ingestion." },
    },
    {
      layer: "Orchestration",
      desc: "Deciding what work gets done, by whom, in what order",
      oc:  { level: "partial", notes: "Session routing and sub-agent spawning (depth-0→1→2). No task graph or fleet management. Sessions are conversation-scoped." },
      gt:  { level: "full",    notes: "Mayor dispatches beads via MEOW. Convoy tracking. Agent presets per cost tier. Circuit breaker (MaxBeadRespawns). Witness detects stuck agents." },
      bd:  { level: "passive", notes: "Provides the task graph that orchestrators read. bd ready returns next unblocked tasks. Does NOT make routing decisions." },
    },
    {
      layer: "Fleet Management",
      desc: "Spawning, monitoring, and killing parallel agent processes",
      oc:  { level: "partial", notes: "Sub-agents up to depth-2. UUID-addressed sessions. Command queue serializes per session. No worktree isolation." },
      gt:  { level: "full",    notes: "Git worktree isolation per Polecat. Witness monitors lifecycle. Deacon for Town-level health. tmux-based process management. séance protocol for context handoff." },
      bd:  { level: "none",    notes: "No process management. Agents are external to Beads." },
    },
    {
      layer: "Skill / Tool Registry",
      desc: "How capabilities are defined, stored, discovered, and invoked",
      oc:  { level: "full",    notes: "SKILL.md with YAML frontmatter. ClawHub marketplace (5400+ skills). Lazy loading: compact XML list at boot, full content on demand. Lobster for deterministic YAML workflows." },
      gt:  { level: "partial", notes: "Delegates to Claude Code's native skill system. Agent presets define which tool runs. No independent registry." },
      bd:  { level: "none",    notes: "No tool or skill registry. bd commands are the only interface." },
    },
    {
      layer: "Memory & State",
      desc: "What persists across sessions; what agents share",
      oc:  { level: "full",    notes: "3-tier: session JSONL (append-only) + daily .md logs + curated MEMORY.md. sqlite-vec for embeddings. Compaction when context fills. Plain files on disk — git-backupable." },
      gt:  { level: "partial", notes: "Git-backed hooks for handoff. Dolt mail + convoy state. No semantic/vector memory. State lives in git repo — durable but not searchable." },
      bd:  { level: "full",    notes: "The dedicated memory layer. Hash-addressed task graph. Dolt v-SQL backend. bd prime injects ~1-2K tokens of workflow context. Topological sort server-side. Append-only JSONL in legacy mode." },
    },
    {
      layer: "Quality / Verification",
      desc: "Automated gates that validate agent output before it's accepted",
      oc:  { level: "none",    notes: "No quality gates. Agent output is whatever the model produces. Lobster workflows can add structure but no CI integration." },
      gt:  { level: "partial", notes: "CI integration via git. Refinery handles merge queue. No automated test enforcement. Auto-merges even with failing CI (documented risk)." },
      bd:  { level: "none",    notes: "No quality gates. Task status (open/claimed/closed) only. No test tracking." },
    },
    {
      layer: "Observability",
      desc: "Visibility into what's happening across the system",
      oc:  { level: "partial", notes: "Web UI + macOS app + CLI dashboard. Flat files = grep-able logs. No distributed traces. No cost attribution per task." },
      gt:  { level: "partial", notes: "tmux panes per agent. Convoy status dashboard. Mail system for inter-agent comms. No OpenTelemetry. No unified trace across all agents." },
      bd:  { level: "partial", notes: "Task graph is queryable via bd commands. No dashboard. Dolt history provides an audit trail. No cost tracking." },
    },
    {
      layer: "Security / Governance",
      desc: "Sandboxing, permissions, audit, identity",
      oc:  { level: "poor",    notes: "CVE-2026-25253 (CVSS 8.8). 26% of audited ClawHub skills had vulnerabilities. No sandbox. Open publish model for skills." },
      gt:  { level: "partial", notes: "Git worktrees provide filesystem isolation between agents. No network sandboxing. No RBAC. Single-user design." },
      bd:  { level: "partial", notes: "Hash IDs prevent accidental overwrites. Dolt history provides immutable audit trail. No access control or identity layer." },
    },
  ];

  const levels = {
    full:    { label: "Full",    color: C.bridge },
    partial: { label: "Partial", color: C.warn },
    passive: { label: "Passive", color: C.gt },
    none:    { label: "None",    color: C.textFaint },
    poor:    { label: "Poor",    color: C.gap },
  };

  const [hover, setHover] = useState(null);

  return (
    <div style={{ padding: "28px 20px" }}>
      <h2 style={{ color: C.text, fontFamily: "'Georgia',serif", fontSize: 20, fontWeight: 400, marginBottom: 6 }}>
        Layer Coverage Breakdown
      </h2>
      <p style={{ color: C.textDim, fontSize: 12, marginBottom: 24, lineHeight: 1.7 }}>
        Eight architectural layers. Three frameworks. Where does each one actually play?
        Hover any row for detail.
      </p>

      {/* Header */}
      <div style={{ display: "grid", gridTemplateColumns: "160px 1fr 1fr 1fr", gap: 8, marginBottom: 8 }}>
        {["Layer", "OpenClaw", "Gastown", "Beads"].map((h, i) => (
          <div key={h} style={{
            color: i === 0 ? C.textDim : [C.oc, C.gt, C.bd][i - 1],
            fontSize: 11, fontWeight: 700, fontFamily: "monospace",
            letterSpacing: 1, padding: "4px 0",
            textAlign: i === 0 ? "left" : "center",
          }}>{h}</div>
        ))}
      </div>

      {rows.map((row, i) => {
        const cols = [row.oc, row.gt, row.bd];
        const fwColors = [C.oc, C.gt, C.bd];
        return (
          <div key={row.layer}
            onMouseEnter={() => setHover(i)}
            onMouseLeave={() => setHover(null)}
            style={{
              display: "grid",
              gridTemplateColumns: "160px 1fr 1fr 1fr",
              gap: 8, marginBottom: 8,
              background: hover === i ? C.surface2 : "transparent",
              borderRadius: 8, padding: "2px 0",
              transition: "background 0.15s",
            }}>
            {/* Layer label */}
            <div style={{ padding: "10px 8px" }}>
              <div style={{ color: C.text, fontSize: 12, fontWeight: 600, marginBottom: 2 }}>{row.layer}</div>
              <div style={{ color: C.textDim, fontSize: 9, lineHeight: 1.4 }}>{row.desc}</div>
            </div>

            {/* Coverage cells */}
            {cols.map((col, ci) => {
              const lv = levels[col.level];
              return (
                <div key={ci} style={{
                  background: C.surface,
                  border: `1px solid ${lv.color}22`,
                  borderTop: `2px solid ${lv.color}`,
                  borderRadius: "0 0 6px 6px",
                  padding: "8px 10px",
                }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 5 }}>
                    <div style={{
                      width: 8, height: 8, borderRadius: "50%",
                      background: lv.color,
                    }} />
                    <span style={{ color: lv.color, fontSize: 10, fontFamily: "monospace", letterSpacing: 1 }}>
                      {lv.label}
                    </span>
                  </div>
                  {hover === i && (
                    <div style={{ color: C.textDim, fontSize: 10, lineHeight: 1.5 }}>{col.notes}</div>
                  )}
                </div>
              );
            })}
          </div>
        );
      })}

      {/* Legend */}
      <div style={{ display: "flex", gap: 16, marginTop: 20, flexWrap: "wrap" }}>
        {Object.entries(levels).map(([k, v]) => (
          <div key={k} style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <div style={{ width: 8, height: 8, borderRadius: "50%", background: v.color }} />
            <span style={{ color: C.textDim, fontSize: 10, fontFamily: "monospace" }}>{v.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════
   TAB 3 — CONNECTIONS
═══════════════════════════════════════════════════════════ */
function Connections() {
  const [active, setActive] = useState(null);

  const connections = [
    {
      id: "gt-bd",
      from: "Gastown",   fromColor: C.gt,
      to:   "Beads",     toColor:   C.bd,
      status: "real",
      title: "Gastown uses Beads as its task graph backend",
      detail: "This is the primary real connection. Gastown's Mayor creates beads (atomic work items) via bd create, dispatches them via MEOW (Mayor-Enhanced Orchestration Workflow), and closes them via bd close. The Dolt database underpins both Beads' task storage AND Gastown's mail system — they share the same data substrate.",
      protocol: "bd create / bd ready / bd update --claim / bd close / gt mail",
      direction: "Gastown writes task lifecycle events to Beads. Beads provides topological ordering back.",
      limitation: "Gastown's Polecats don't directly query Beads — they receive work via MEOW dispatch. The Mayor is the only agent actively reading bd ready.",
    },
    {
      id: "gt-dolt",
      from: "Gastown",   fromColor: C.gt,
      to:   "Dolt",      toColor:   C.bd,
      status: "real",
      title: "Both Gastown and Beads share the Dolt substrate",
      detail: "Dolt is a version-controlled SQL database with git semantics. Beads v0.50+ uses it as its primary backend (replacing JSONL). Gastown uses it for its mail system (gt mail). This means task state and inter-agent messages live in the same branching database — both can be audited, rolled back, and diffed like code.",
      protocol: "Dolt SQL API + push/pull for sync",
      direction: "Both frameworks read/write to Dolt. Dolt provides the shared state substrate.",
      limitation: "The two namespaces aren't formally unified — Beads tasks and Gastown mail are separate tables, not linked by foreign keys.",
    },
    {
      id: "oc-skill",
      from: "OpenClaw",  fromColor: C.oc,
      to:   "SKILL.md",  toColor:   C.bridge,
      status: "real",
      title: "OpenClaw implements the SKILL.md standard",
      detail: "OpenClaw uses SKILL.md files as its primary skill format. Each skill is a directory with YAML frontmatter (name, description, metadata.openclaw with requires/bins/env/config) plus markdown instructions. A compact XML list (~24 tokens per skill) is injected at session start; full content loads on-demand. 5400+ skills on ClawHub follow this format.",
      protocol: "SKILL.md YAML frontmatter + markdown body",
      direction: "OpenClaw reads SKILL.md files. Agents invoke them via the Skill tool.",
      limitation: "Gastown delegates to Claude Code's native skill system — it doesn't implement its own SKILL.md reader.",
    },
    {
      id: "oc-bd",
      from: "OpenClaw",  fromColor: C.oc,
      to:   "Beads",     toColor:   C.bd,
      status: "missing",
      title: "OpenClaw agents can't read Beads task graphs",
      detail: "An OpenClaw agent managing a conversation could theoretically query Beads to understand what coding work is in progress — but there's no bridge. The SKILL.md system could provide a Beads skill that wraps bd commands, but it doesn't exist by default. An OpenClaw agent has no awareness of Gastown convoy status.",
      protocol: "Would need: Beads MCP server or bd CLI wrapped as an OpenClaw skill",
      direction: "Missing: OpenClaw → bd ready / bd prime",
      limitation: "The most obvious missing connection. You could build it in a day with an MCP server wrapping Beads CLI.",
    },
    {
      id: "oc-gt",
      from: "OpenClaw",  fromColor: C.oc,
      to:   "Gastown",   toColor:   C.gt,
      status: "missing",
      title: "No way for OpenClaw to dispatch Gastown convoys",
      detail: "If you receive a feature request via WhatsApp (OpenClaw) and want to spin up a Gastown convoy to implement it, there's no bridge. OpenClaw can run shell commands — theoretically could run gt sling — but there's no purpose-built integration, no status feedback loop, and no way for Gastown convoy updates to flow back to the WhatsApp conversation.",
      protocol: "Would need: Gastown MCP server or CLI wrapper skill + status webhook back to OpenClaw",
      direction: "Missing: OpenClaw → gt sling → [work happens] → convoy status → OpenClaw notification",
      limitation: "This is the biggest architectural gap across the three frameworks.",
    },
    {
      id: "bd-gt-shared",
      from: "Beads",     fromColor: C.bd,
      to:   "Polecats",  toColor:   C.gt,
      status: "partial",
      title: "Polecats can read Beads but don't by default",
      detail: "Gastown Polecats are Claude Code instances. Claude Code can run bd commands. So a Polecat could claim its own work item, update progress, and close it — but Gastown doesn't wire this up by default. The Mayor uses Beads; the Polecats just receive dispatched instructions via MEOW. There's a gap between what's possible and what's implemented.",
      protocol: "bd update --claim / bd close (available but not default-wired)",
      direction: "Partial: Polecats could use Beads but don't by default",
      limitation: "Making Polecats Beads-aware would enable true agent-to-agent task handoff without the Mayor as intermediary.",
    },
  ];

  const statusStyle = {
    real:    { color: C.bridge, label: "REAL CONNECTION" },
    missing: { color: C.gap,    label: "MISSING BRIDGE" },
    partial: { color: C.warn,   label: "PARTIAL / POSSIBLE" },
  };

  // SVG positions
  const OC = { x: 130, y: 200 };
  const GT = { x: 400, y: 100 };
  const BD = { x: 400, y: 300 };

  const svgEdges = [
    { from: GT, to: BD,  color: C.bridge, dash: false, label: "uses (task graph)" },
    { from: OC, to: BD,  color: C.gap,    dash: true,  label: "missing bridge" },
    { from: OC, to: GT,  color: C.gap,    dash: true,  label: "missing bridge" },
    { from: GT, to: BD,  color: C.bd,     dash: true,  label: "Dolt substrate",  offset: 10 },
    { from: BD, to: GT,  color: C.warn,   dash: true,  label: "Polecats (partial)", offset: -10 },
  ];

  return (
    <div style={{ padding: "28px 20px" }}>
      <h2 style={{ color: C.text, fontFamily: "'Georgia',serif", fontSize: 20, fontWeight: 400, marginBottom: 6 }}>
        How They Connect (and Don't)
      </h2>
      <p style={{ color: C.textDim, fontSize: 12, marginBottom: 24, lineHeight: 1.7 }}>
        One real connection. One shared substrate. Three missing bridges. Click any card to expand.
      </p>

      {/* SVG overview */}
      <svg viewBox="0 0 560 400" style={{
        background: C.surface, borderRadius: 10,
        border: `1px solid ${C.border}`,
        width: "100%", marginBottom: 24,
      }}>
        {/* Real edges */}
        <line x1={GT.x} y1={GT.y} x2={BD.x} y2={BD.y}
          stroke={C.bridge} strokeWidth={2} />
        <text x={(GT.x+BD.x)/2 + 12} y={(GT.y+BD.y)/2}
          fill={C.bridge} fontSize={9} fontFamily="monospace">uses Beads</text>

        {/* Missing */}
        <line x1={OC.x} y1={OC.y} x2={BD.x} y2={BD.y}
          stroke={C.gap} strokeWidth={1.5} strokeDasharray="5,4" />
        <line x1={OC.x} y1={OC.y} x2={GT.x} y2={GT.y}
          stroke={C.gap} strokeWidth={1.5} strokeDasharray="5,4" />

        {/* Partial */}
        <line x1={BD.x} y1={BD.y - 8} x2={GT.x} y2={GT.y + 8}
          stroke={C.warn} strokeWidth={1} strokeDasharray="3,5" />

        {/* Nodes */}
        {[
          { ...OC, color: C.oc, name: "OpenClaw",  sub: "Interface + Runtime" },
          { ...GT, color: C.gt, name: "Gastown",   sub: "Orchestrator + Fleet" },
          { ...BD, color: C.bd, name: "Beads",     sub: "Task Memory" },
        ].map(n => (
          <g key={n.name}>
            <circle cx={n.x} cy={n.y} r={52}
              fill={n.color + "14"} stroke={n.color + "55"} strokeWidth={1.5} />
            <text x={n.x} y={n.y - 8} textAnchor="middle"
              fill={n.color} fontSize={13} fontWeight="700" fontFamily="'Georgia',serif">{n.name}</text>
            <text x={n.x} y={n.y + 8} textAnchor="middle"
              fill={n.color + "88"} fontSize={9} fontFamily="monospace">{n.sub}</text>
          </g>
        ))}

        {/* Dolt label */}
        <rect x={310} y={180} width={100} height={28} rx={6}
          fill={C.bd + "22"} stroke={C.bd + "44"} />
        <text x={360} y={198} textAnchor="middle"
          fill={C.bd} fontSize={10} fontFamily="monospace">Dolt (shared DB)</text>
        <line x1={360} y1={180} x2={GT.x + 10} y2={GT.y + 40}
          stroke={C.bd + "55"} strokeWidth={1} strokeDasharray="3,3" />
        <line x1={360} y1={208} x2={BD.x + 10} y2={BD.y - 40}
          stroke={C.bd + "55"} strokeWidth={1} strokeDasharray="3,3" />

        {/* Legend */}
        {[
          { x: 20, color: C.bridge, dash: false, label: "Real" },
          { x: 80, color: C.warn,   dash: true,  label: "Partial" },
          { x: 150, color: C.gap,   dash: true,  label: "Missing" },
        ].map(l => (
          <g key={l.label}>
            <line x1={l.x} y1={370} x2={l.x + 30} y2={370}
              stroke={l.color} strokeWidth={2} strokeDasharray={l.dash ? "5,3" : "none"} />
            <text x={l.x + 35} y={374}
              fill={l.color} fontSize={9} fontFamily="monospace">{l.label}</text>
          </g>
        ))}
      </svg>

      {/* Cards */}
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {connections.map(conn => {
          const st = statusStyle[conn.status];
          const isOpen = active === conn.id;
          return (
            <div key={conn.id} onClick={() => setActive(isOpen ? null : conn.id)}
              style={{
                background: C.surface,
                border: `1px solid ${isOpen ? st.color + "55" : C.border}`,
                borderLeft: `3px solid ${st.color}`,
                borderRadius: 8, padding: "12px 16px",
                cursor: "pointer", transition: "all 0.15s",
              }}>
              <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <Tag color={st.color} small>{st.label}</Tag>
                <span style={{
                  color: conn.fromColor, fontSize: 12, fontWeight: 600,
                }}>{conn.from}</span>
                <span style={{ color: C.textDim, fontSize: 11 }}>
                  {conn.status === "missing" ? "✗⟶" : "→"}
                </span>
                <span style={{ color: conn.toColor, fontSize: 12, fontWeight: 600 }}>{conn.to}</span>
                <span style={{ flex: 1 }} />
                <span style={{ color: C.text, fontSize: 12 }}>{conn.title}</span>
              </div>

              {isOpen && (
                <div style={{ marginTop: 14, paddingTop: 14, borderTop: `1px solid ${C.border}` }}>
                  <p style={{ color: C.text, fontSize: 12, lineHeight: 1.7, margin: "0 0 12px" }}>{conn.detail}</p>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                    <div style={{ background: C.surface2, borderRadius: 6, padding: "8px 10px" }}>
                      <div style={{ color: C.textDim, fontSize: 9, letterSpacing: 1, marginBottom: 4, textTransform: "uppercase" }}>Protocol / Interface</div>
                      <div style={{ color: st.color + "cc", fontSize: 10, fontFamily: "monospace", lineHeight: 1.5 }}>{conn.protocol}</div>
                    </div>
                    <div style={{ background: C.surface2, borderRadius: 6, padding: "8px 10px" }}>
                      <div style={{ color: C.textDim, fontSize: 9, letterSpacing: 1, marginBottom: 4, textTransform: "uppercase" }}>Limitation</div>
                      <div style={{ color: C.warn + "cc", fontSize: 10, lineHeight: 1.5 }}>{conn.limitation}</div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════
   TAB 4 — END-TO-END FLOW
═══════════════════════════════════════════════════════════ */
function EndToEndFlow() {
  const [scenario, setScenario] = useState("ideal");

  const scenarios = {
    real: {
      label: "Reality Today",
      color: C.warn,
      desc: "How the three frameworks actually interact today — Gastown uses Beads, OpenClaw is isolated.",
      steps: [
        { fw: "oc",  actor: "OpenClaw",            action: "Receives feature request via WhatsApp",            note: "Normalized to internal message format" },
        { fw: "oc",  actor: "OpenClaw Agent",       action: "Responds conversationally, maybe writes some code", note: "Unaware of Gastown or Beads" },
        { fw: "—",   actor: "Human",                action: "Manually copies request, opens terminal",          note: "THE GAP — human is the integration layer" },
        { fw: "gt",  actor: "Gastown Mayor",        action: "Receives task, decomposes into beads",             note: "bd create for each work item" },
        { fw: "bd",  actor: "Beads",                action: "Stores task graph with dependencies",              note: "bd ready returns unblocked tasks" },
        { fw: "gt",  actor: "MEOW Dispatch",        action: "Mayor dispatches convoy to Polecats",              note: "Each Polecat gets a bead" },
        { fw: "gt",  actor: "Polecat(s)",           action: "Work in isolated git worktrees",                   note: "Parallel, no Beads awareness" },
        { fw: "gt",  actor: "Witness",              action: "Monitors Polecat lifecycle, detects stuck",        note: "Circuit breaker on respawns" },
        { fw: "bd",  actor: "Beads",                action: "Mayor closes beads as Polecats complete",          note: "bd close triggers dependent beads" },
        { fw: "gt",  actor: "Refinery",             action: "Processes merge queue",                            note: "Handles conflicts" },
        { fw: "—",   actor: "Human",                action: "Manually reports completion back to WhatsApp",     note: "THE GAP — still manual" },
        { fw: "oc",  actor: "OpenClaw",             action: "Sends completion update",                          note: "No awareness of what was built" },
      ],
    },
    ideal: {
      label: "Ideal (Bridged)",
      color: C.bridge,
      desc: "How they'd work together with a thin bridge layer connecting OpenClaw to Gastown + Beads.",
      steps: [
        { fw: "oc",     actor: "OpenClaw",              action: "Receives feature request via WhatsApp",               note: "Normalized event with intent + priority" },
        { fw: "bridge", actor: "Bridge MCP Server",     action: "Classifies intent as coding task, routes to Gastown", note: "NEW: thin adapter layer" },
        { fw: "gt",     actor: "Gastown Mayor",         action: "Creates beads + convoy from intent",                  note: "bd create with dependency chain" },
        { fw: "bd",     actor: "Beads",                 action: "Task graph established, bd ready returns first batch", note: "Dolt backend, hash IDs" },
        { fw: "gt",     actor: "MEOW",                  action: "Dispatches Polecats to worktrees",                    note: "Parallel execution begins" },
        { fw: "gt",     actor: "Polecats",              action: "Implement with TDD in isolated branches",             note: "Each claims own bead via bd update --claim" },
        { fw: "bd",     actor: "Beads",                 action: "Progress queryable: bd prime shows convoy status",    note: "NEW: Polecats write to Beads" },
        { fw: "gt",     actor: "Witness",               action: "Detects completion, triggers Refinery",               note: "Circuit breaker active" },
        { fw: "gt",     actor: "Refinery",              action: "Merges branches, resolves conflicts",                 note: "Merge queue processed" },
        { fw: "bridge", actor: "Bridge MCP Server",     action: "Reads convoy completion from Beads + Gastown",        note: "Polls bd prime / convoy status" },
        { fw: "oc",     actor: "OpenClaw Agent",        action: "Sends rich completion update to requester",           note: "Includes diff summary, test results, PR link" },
        { fw: "oc",     actor: "OpenClaw Memory",       action: "Stores completed feature in MEMORY.md",               note: "Long-term retention for future sessions" },
      ],
    },
  };

  const fwStyle = {
    oc:     { color: C.oc,     label: "OpenClaw" },
    gt:     { color: C.gt,     label: "Gastown" },
    bd:     { color: C.bd,     label: "Beads" },
    bridge: { color: C.bridge, label: "Bridge" },
    "—":    { color: C.gap,    label: "Manual Gap" },
  };

  const s = scenarios[scenario];

  return (
    <div style={{ padding: "28px 20px" }}>
      <h2 style={{ color: C.text, fontFamily: "'Georgia',serif", fontSize: 20, fontWeight: 400, marginBottom: 6 }}>
        End-to-End Flow
      </h2>
      <p style={{ color: C.textDim, fontSize: 12, marginBottom: 20, lineHeight: 1.7 }}>
        Tracing a single feature request from WhatsApp to merged PR — what actually happens today vs. what could with a thin bridge.
      </p>

      <div style={{ display: "flex", gap: 8, marginBottom: 24 }}>
        {Object.entries(scenarios).map(([k, v]) => (
          <button key={k} onClick={() => setScenario(k)} style={{
            background: scenario === k ? v.color + "22" : "transparent",
            border: `1px solid ${scenario === k ? v.color : C.border}`,
            borderRadius: 6, padding: "7px 16px",
            color: scenario === k ? v.color : C.textDim,
            fontSize: 12, cursor: "pointer", fontFamily: "inherit",
          }}>{v.label}</button>
        ))}
      </div>

      <p style={{ color: C.textDim, fontSize: 12, marginBottom: 20, fontStyle: "italic" }}>{s.desc}</p>

      {/* Framework key */}
      <div style={{ display: "flex", gap: 12, marginBottom: 20, flexWrap: "wrap" }}>
        {Object.entries(fwStyle).map(([k, v]) => (
          <div key={k} style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <div style={{ width: 10, height: 10, borderRadius: "50%", background: v.color }} />
            <span style={{ color: v.color, fontSize: 10, fontFamily: "monospace" }}>{v.label}</span>
          </div>
        ))}
      </div>

      {/* Flow */}
      <div style={{ position: "relative" }}>
        <div style={{
          position: "absolute", left: 116, top: 16, bottom: 16,
          width: 2,
          background: `linear-gradient(to bottom, transparent, ${s.color}55, transparent)`,
        }} />

        {s.steps.map((step, i) => {
          const fw = fwStyle[step.fw];
          const isGap = step.fw === "—";
          return (
            <div key={i} style={{
              display: "flex", alignItems: "center", gap: 12, marginBottom: 8,
            }}>
              {/* Step num */}
              <div style={{
                width: 26, height: 26, borderRadius: "50%", flexShrink: 0,
                background: fw.color + "22",
                border: `1px solid ${fw.color}55`,
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 9, color: fw.color, fontFamily: "monospace",
              }}>{i + 1}</div>

              {/* Framework tag */}
              <div style={{ width: 76, flexShrink: 0, textAlign: "right" }}>
                <Tag color={fw.color} small>{fw.label}</Tag>
              </div>

              {/* Spine dot */}
              <div style={{
                width: 10, height: 10, borderRadius: "50%",
                background: isGap ? C.gap : fw.color,
                flexShrink: 0, zIndex: 1, border: isGap ? `2px solid ${C.gap}` : "none",
              }} />

              {/* Content */}
              <div style={{
                flex: 1,
                background: isGap ? C.gap + "0d" : C.surface,
                border: `1px solid ${isGap ? C.gap + "44" : fw.color + "1a"}`,
                borderRadius: 6, padding: "8px 12px",
              }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 8 }}>
                  <div>
                    <span style={{ color: fw.color, fontSize: 11, fontWeight: 600 }}>{step.actor}: </span>
                    <span style={{ color: C.text, fontSize: 11 }}>{step.action}</span>
                  </div>
                  <span style={{ color: C.textDim, fontSize: 9, flexShrink: 0, lineHeight: 1.5, maxWidth: 160, textAlign: "right" }}>{step.note}</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {scenario === "ideal" && (
        <div style={{
          marginTop: 20, background: C.bridge + "0d",
          border: `1px solid ${C.bridge}22`, borderRadius: 8, padding: "14px 16px",
        }}>
          <div style={{ color: C.bridge, fontSize: 12, fontWeight: 700, marginBottom: 6 }}>
            The Bridge Layer — What It Actually Is
          </div>
          <p style={{ color: C.textDim, fontSize: 12, lineHeight: 1.7, margin: 0 }}>
            The "Bridge MCP Server" is a thin adapter — ~200 lines of code — that exposes Gastown's CLI and Beads' CLI as MCP tools that OpenClaw can call. It doesn't add intelligence. It just translates: incoming OpenClaw intent → gt sling + bd commands, and convoy status → outbound OpenClaw notification. This is what's missing. The frameworks are compatible. They're just not wired.
          </p>
        </div>
      )}
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════
   TAB 5 — GAPS
═══════════════════════════════════════════════════════════ */
function Gaps() {
  const gaps = [
    {
      sev: "critical", color: C.gap,
      title: "OpenClaw has no awareness of Gastown or Beads",
      which: ["OpenClaw ↔ Gastown", "OpenClaw ↔ Beads"],
      impact: "The human is the integration layer. A request arrives via WhatsApp, a human copies it to a terminal, starts a Gastown convoy, waits, then manually reports back. The two richest agentic systems can't talk to each other.",
      fix: "A thin MCP server wrapping gt sling, bd ready, and bd prime. OpenClaw skill calls the MCP server. Convoy status polls back. Two-way bridge, ~200 lines.",
      effort: "1–2 days",
    },
    {
      sev: "critical", color: C.gap,
      title: "Gastown auto-merges with failing CI",
      which: ["Gastown internal"],
      impact: "The Refinery will merge branches even when CI is red. DoltHub team documented a hard git reset --hard after Gastown merged broken code. There's no enforced quality gate before merge.",
      fix: "Merge policy gate: Refinery checks CI status before merging. Hard block on red. Babysitter's convergent loop pattern is the right model — iterate until gates pass.",
      effort: "Gastown PR / config flag",
    },
    {
      sev: "high", color: C.warn,
      title: "Polecats don't write back to Beads",
      which: ["Gastown ↔ Beads"],
      impact: "The Mayor creates and closes beads; Polecats receive work via MEOW but don't interact with Beads directly. This means a Polecat can't update progress, block dependents based on runtime discoveries, or close its own bead. The Mayor is a bottleneck.",
      fix: "Wire bd update --claim and bd close into the Polecat's standard workflow. Every Polecat should claim its bead at spawn and close it at completion — Mayor just creates and reads.",
      effort: "Gastown hook changes",
    },
    {
      sev: "high", color: C.warn,
      title: "No cost-aware routing in Gastown",
      which: ["Gastown internal"],
      impact: "Gastown requires 3+ Claude Pro Max subscriptions. Estimated $100/hr burn rate during active use. There's no circuit breaker that downgrades model tier when budget is exhausted, no per-task cost estimate before dispatch, no daily spend cap.",
      fix: "Budget middleware: estimate tokens per bead type → running spend total → auto-downgrade to economy/budget tier → hard kill at ceiling. Gastown's existing cost tiers (standard/economy/budget) are the right primitives — just need budget-aware selection.",
      effort: "Medium — requires token estimation per bead",
    },
    {
      sev: "high", color: C.warn,
      title: "OpenClaw skill security is broken at ecosystem scale",
      which: ["OpenClaw / ClawHub"],
      impact: "26% CVE rate in audited ClawHub skills. CVE-2026-25253 (CVSS 8.8) enabled RCE on 21K+ exposed instances. Community skills execute in the same process as the agent with no sandboxing.",
      fix: "WASM-sandboxed skill execution + signed manifests + permission declarations per skill + community review pipeline before publication. Superpowers' markdown-only approach partially mitigates this — instructions can't execute arbitrary code.",
      effort: "Significant architectural change to OpenClaw",
    },
    {
      sev: "medium", color: C.bd,
      title: "Beads has no memory of what was learned from completed tasks",
      which: ["Beads internal"],
      impact: "Beads tracks task state (open/claimed/closed) but not task outcomes. What was learned? What approach failed? What pattern worked? A closed bead carries no semantic payload that future tasks can query.",
      fix: "Add a lessons/outcome field to bead close. bd close --reason 'Used X approach, failed with Y, succeeded with Z'. Vector-index these outcomes. bd similar-to returns past beads with semantic overlap — giving agents precedent before starting.",
      effort: "Medium — Beads API + vector index",
    },
    {
      sev: "medium", color: C.bd,
      title: "Beads performance degrades beyond ~500 issues",
      which: ["Beads internal"],
      impact: "JSONL files exceeding ~25K tokens break agents that read files directly. The Rust reimplementation (br) helps but the Dolt backend introduces its own latency at scale.",
      fix: "Partition by project + time window. Archive closed beads to cold storage. Keep working set < 200 issues in hot path. The Rust reimplementation (br) is the right long-term answer.",
      effort: "Medium — data partitioning strategy",
    },
    {
      sev: "medium", color: C.oc,
      title: "OpenClaw has no awareness when context window fills",
      which: ["OpenClaw internal"],
      impact: "When a long session fills the context window, the compaction process is lossy — older turns are summarized and the original is lost. There's no GUPP-equivalent hook to hand off to a fresh session cleanly.",
      fix: "Adopt Gastown's séance protocol: when context fills, spawn a new session that reads the old session's MEMORY.md, runs a séance (queries the old session to understand unfinished work), then continues. Bidirectional handoff.",
      effort: "Medium — requires new session spawn pattern",
    },
    {
      sev: "low", color: C.textDim,
      title: "No shared observability across the three frameworks",
      which: ["All three"],
      impact: "Three separate dashboards (OpenClaw web UI, Gastown tmux panes, Beads CLI). A feature request entering via OpenClaw and implemented via Gastown+Beads has no single trace that follows it end-to-end.",
      fix: "Correlation ID injected at ingest (OpenClaw). Passed to Gastown convoy metadata. Stored on each bead. OpenTelemetry spans emitted by each framework's bridge adapter. Unified trace in Jaeger/Datadog/SigNoz.",
      effort: "High — requires framework-level OTel instrumentation",
    },
  ];

  return (
    <div style={{ padding: "28px 20px" }}>
      <h2 style={{ color: C.text, fontFamily: "'Georgia',serif", fontSize: 20, fontWeight: 400, marginBottom: 6 }}>
        Gaps Between the Three Frameworks
      </h2>
      <p style={{ color: C.textDim, fontSize: 12, marginBottom: 24, lineHeight: 1.7 }}>
        Nine gaps — some between the frameworks, some internal. Severity ranked. Each with a concrete fix and effort estimate.
      </p>

      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {gaps.map((g, i) => (
          <div key={i} style={{
            background: C.surface,
            border: `1px solid ${C.border}`,
            borderLeft: `3px solid ${g.color}`,
            borderRadius: 8, padding: "14px 18px",
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8, flexWrap: "wrap" }}>
              <Tag color={g.color}>{g.sev.toUpperCase()}</Tag>
              <span style={{ color: C.text, fontSize: 13, fontWeight: 600, flex: 1 }}>{g.title}</span>
              {g.effort && (
                <span style={{ color: C.textDim, fontSize: 10, fontFamily: "monospace" }}>
                  effort: {g.effort}
                </span>
              )}
            </div>

            <div style={{ display: "flex", gap: 6, marginBottom: 10, flexWrap: "wrap" }}>
              {g.which.map(w => (
                <Tag key={w} color={C.textDim} small>{w}</Tag>
              ))}
            </div>

            <p style={{ color: C.textDim, fontSize: 12, lineHeight: 1.6, margin: "0 0 10px" }}>{g.impact}</p>

            <div style={{
              background: C.bridge + "0d", border: `1px solid ${C.bridge}22`,
              borderRadius: 6, padding: "8px 12px",
            }}>
              <span style={{ color: C.bridge, fontSize: 10, fontWeight: 700, letterSpacing: 1 }}>FIX → </span>
              <span style={{ color: C.bridge + "cc", fontSize: 11, lineHeight: 1.5 }}>{g.fix}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════
   ROOT
═══════════════════════════════════════════════════════════ */
export default function App() {
  const [tab, setTab] = useState("what");

  const panels = {
    what:        <WhatEachDoes />,
    layers:      <LayerBreakdown />,
    connections: <Connections />,
    flow:        <EndToEndFlow />,
    gaps:        <Gaps />,
  };

  return (
    <div style={{ background: C.bg, minHeight: "100vh", fontFamily: "'Georgia',serif", color: C.text }}>
      {/* Header */}
      <div style={{ background: C.surface, borderBottom: `1px solid ${C.border}`, padding: "20px 20px 0" }}>
        <div style={{ fontSize: 10, color: C.textFaint, letterSpacing: 3, fontFamily: "monospace", marginBottom: 4 }}>
          LAYER ONE — FOUNDATION REPOS
        </div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 16, marginBottom: 14, flexWrap: "wrap" }}>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 400, color: C.text }}>
            OpenClaw · Gastown · Beads
          </h1>
          <div style={{ display: "flex", gap: 10 }}>
            {[
              { name: "OpenClaw", color: C.oc },
              { name: "Gastown",  color: C.gt },
              { name: "Beads",    color: C.bd },
            ].map(fw => (
              <span key={fw.name} style={{
                color: fw.color, fontSize: 11, fontFamily: "monospace",
                background: fw.color + "14", border: `1px solid ${fw.color}33`,
                borderRadius: 4, padding: "2px 8px",
              }}>{fw.name}</span>
            ))}
          </div>
        </div>
        <div style={{ display: "flex", gap: 2, overflowX: "auto" }}>
          {TABS.map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              background: tab === t.id ? C.gt + "22" : "transparent",
              border: "none",
              borderBottom: `2px solid ${tab === t.id ? C.gt : "transparent"}`,
              borderRadius: "6px 6px 0 0",
              padding: "8px 16px",
              color: tab === t.id ? C.gt : C.textDim,
              fontSize: 12, cursor: "pointer", fontFamily: "inherit",
              whiteSpace: "nowrap", transition: "all 0.15s",
            }}>{t.label}</button>
          ))}
        </div>
      </div>

      <div style={{ maxWidth: 860, margin: "0 auto" }}>
        {panels[tab]}
      </div>
    </div>
  );
}
