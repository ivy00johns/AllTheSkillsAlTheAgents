import { useState } from "react";

const COLORS = {
  bg: "#0a0a0f",
  surface: "#12121a",
  surface2: "#1a1a26",
  border: "#2a2a3e",
  accent1: "#7c6af7",   // purple - orchestration
  accent2: "#4ecdc4",   // teal - memory/state
  accent3: "#f7c04a",   // gold - methodology
  accent4: "#f76e6e",   // red - execution/agents
  accent5: "#6ef7a0",   // green - gaps/missing
  accent6: "#f7a06e",   // orange - new patterns
  text: "#e8e8f0",
  textDim: "#7878a0",
  textFaint: "#4a4a6a",
};

const tabs = [
  { id: "layers", label: "Layer Map" },
  { id: "connections", label: "Connection Graph" },
  { id: "dataflow", label: "Data & State Flow" },
  { id: "gaps", label: "What's Missing" },
  { id: "orchestrator", label: "Ideal Orchestrator" },
];

// ─── LAYER MAP ────────────────────────────────────────────────────────────────
function LayerMap() {
  const [hover, setHover] = useState(null);

  const layers = [
    {
      id: "interface",
      label: "01 — Interface Layer",
      color: COLORS.accent6,
      desc: "How humans & systems reach agents",
      frameworks: [
        { name: "OpenClaw", role: "WhatsApp / Telegram / Discord / SMS / iMessage gateway", color: COLORS.accent6 },
        { name: "Dorothy", role: "Desktop GUI multi-agent Kanban", color: COLORS.accent6 },
        { name: "GStack", role: "Claude Code slash-command UX", color: COLORS.accent6 },
        { name: "Babysitter Breakpoints", role: "Web UI for human approval gates", color: COLORS.accent6 },
        { name: "Composio Dashboard", role: "Next.js SSE live fleet view", color: COLORS.accent6 },
      ],
      missing: "No unified event bus. Each has its own ingest format.",
    },
    {
      id: "orchestration",
      label: "02 — Orchestration Layer",
      color: COLORS.accent1,
      desc: "Who decides what gets done and by whom",
      frameworks: [
        { name: "Gastown Mayor/MEOW", role: "Convoy dispatch, bead routing, agent presets", color: COLORS.accent1 },
        { name: "Composio AO Orchestrator", role: "Meta-agent issuing CLI commands to worker fleet", color: COLORS.accent1 },
        { name: "Mastra Supervisor", role: "TypeScript delegation hooks + task completion scorers", color: COLORS.accent1 },
        { name: "Babysitter Process", role: "JS function is the authority — code routes, not LLM", color: COLORS.accent1 },
        { name: "Superpowers Meta-Skill", role: "Prompt-driven routing via SKILL.md description matching", color: COLORS.accent1 },
      ],
      missing: "No cross-framework orchestrator handoff. No cost-aware routing. No fallback chains.",
    },
    {
      id: "methodology",
      label: "03 — Methodology Layer",
      color: COLORS.accent3,
      desc: "Rules, workflows, and quality gates",
      frameworks: [
        { name: "Superpowers SKILL.md", role: "TDD, dual-review, subagent dispatch as enforced markdown", color: COLORS.accent3 },
        { name: "GStack SKILL.md", role: "Role-personas (CEO/EM/QA) as slash-command workflows", color: COLORS.accent3 },
        { name: "Babysitter Processes", role: "2000+ named processes: TDD, BDD, GSD, Scrum, CC10X", color: COLORS.accent3 },
        { name: "OpenClaw AGENTS.md", role: "Project conventions injected at session start", color: COLORS.accent3 },
      ],
      missing: "No process composition. Can't combine Superpowers TDD with Babysitter BDD in one run.",
    },
    {
      id: "execution",
      label: "04 — Execution Layer",
      color: COLORS.accent4,
      desc: "Where agents actually run and produce work",
      frameworks: [
        { name: "Gastown Polecats", role: "Ephemeral workers in isolated git worktrees", color: COLORS.accent4 },
        { name: "Composio Worker Agents", role: "Claude Code / Codex / Aider per issue in worktree", color: COLORS.accent4 },
        { name: "OpenClaw Sub-Agents", role: "Spawned sessions up to depth-2, UUID-addressed", color: COLORS.accent4 },
        { name: "Superpowers Subagents", role: "Fresh agent per task: implementer + 2 reviewers", color: COLORS.accent4 },
        { name: "Mastra Agent Network", role: "Supervisor + delegated specialists via hooks", color: COLORS.accent4 },
      ],
      missing: "No cross-runtime agent discovery. Claude Code agents can't see Codex agents.",
    },
    {
      id: "memory",
      label: "05 — Memory & State Layer",
      color: COLORS.accent2,
      desc: "What persists, what's shared, what's remembered",
      frameworks: [
        { name: "Beads / Dolt", role: "Git-native task graph: hash IDs, topological sort, bd ready", color: COLORS.accent2 },
        { name: "OpenClaw 3-tier", role: "Session JSONL + daily logs + MEMORY.md + sqlite-vec", color: COLORS.accent2 },
        { name: "Mastra Memory", role: "Working + conversation + semantic recall + observational compaction", color: COLORS.accent2 },
        { name: "Babysitter Journal", role: "Append-only JSONL event source — crash-safe, replayable", color: COLORS.accent2 },
        { name: "Composio Flat Files", role: "key=value metadata per session — grep-able, no DB", color: COLORS.accent2 },
        { name: "Gastown Hooks/Mail", role: "Git-backed hooks + Dolt mail system + convoy state", color: COLORS.accent2 },
      ],
      missing: "No shared memory across frameworks. Mastra agents can't read Beads task graphs.",
    },
    {
      id: "tooling",
      label: "06 — Tool & Skill Registry",
      color: COLORS.accent5,
      desc: "How capabilities are defined, discovered, invoked",
      frameworks: [
        { name: "SKILL.md Standard", role: "Cross-platform: Claude Code, OpenCode, Codex, Gemini CLI", color: COLORS.accent5 },
        { name: "MCP Protocol", role: "Linux Foundation standard — tools as discoverable servers", color: COLORS.accent5 },
        { name: "Mastra createTool()", role: "Zod-typed tools with 15→3% error rate via compat layer", color: COLORS.accent5 },
        { name: "OpenClaw ClawHub", role: "5400+ community skills — 26% had CVEs, unverified", color: COLORS.accent5 },
        { name: "Babysitter Tasks", role: "defineTask() typed I/O, 2000+ built-in process templates", color: COLORS.accent5 },
        { name: "GStack symlinks", role: "13 persona-skills symlinked into .claude/skills/", color: COLORS.accent5 },
      ],
      missing: "No deferred loading standard across frameworks. No sandboxed skill execution.",
    },
  ];

  return (
    <div style={{ padding: "32px 24px" }}>
      <h2 style={{ color: COLORS.text, fontFamily: "'Georgia', serif", fontSize: 22, marginBottom: 8, fontWeight: 400 }}>
        The Six Layers of Agentic Infrastructure
      </h2>
      <p style={{ color: COLORS.textDim, fontSize: 13, marginBottom: 32, lineHeight: 1.6 }}>
        Every framework touches some layers and ignores others. No single one covers all six.
      </p>

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {layers.map((layer, li) => (
          <div
            key={layer.id}
            onMouseEnter={() => setHover(layer.id)}
            onMouseLeave={() => setHover(null)}
            style={{
              background: hover === layer.id ? COLORS.surface2 : COLORS.surface,
              border: `1px solid ${hover === layer.id ? layer.color + "55" : COLORS.border}`,
              borderRadius: 10,
              padding: "16px 20px",
              transition: "all 0.2s",
              cursor: "default",
            }}
          >
            <div style={{ display: "flex", alignItems: "flex-start", gap: 16, marginBottom: 12 }}>
              <div style={{
                width: 4, minWidth: 4, alignSelf: "stretch",
                background: layer.color, borderRadius: 2,
              }} />
              <div style={{ flex: 1 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 4 }}>
                  <span style={{ color: layer.color, fontFamily: "monospace", fontSize: 11, letterSpacing: 2 }}>
                    {layer.label}
                  </span>
                </div>
                <p style={{ color: COLORS.textDim, fontSize: 12, margin: 0 }}>{layer.desc}</p>
              </div>
            </div>

            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginLeft: 20, marginBottom: 10 }}>
              {layer.frameworks.map(fw => (
                <div key={fw.name} style={{
                  background: fw.color + "14",
                  border: `1px solid ${fw.color}33`,
                  borderRadius: 6,
                  padding: "5px 10px",
                  maxWidth: 300,
                }}>
                  <div style={{ color: fw.color, fontSize: 11, fontWeight: 600, marginBottom: 2 }}>{fw.name}</div>
                  <div style={{ color: COLORS.textDim, fontSize: 10, lineHeight: 1.4 }}>{fw.role}</div>
                </div>
              ))}
            </div>

            <div style={{
              marginLeft: 20,
              background: "#f7c04a0e",
              border: "1px solid #f7c04a22",
              borderRadius: 6,
              padding: "6px 10px",
              display: "flex", alignItems: "flex-start", gap: 8,
            }}>
              <span style={{ color: "#f7c04a", fontSize: 10, marginTop: 1 }}>⚠</span>
              <span style={{ color: "#f7c04a99", fontSize: 11 }}>{layer.missing}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── CONNECTION GRAPH ─────────────────────────────────────────────────────────
function ConnectionGraph() {
  const [activeNode, setActiveNode] = useState(null);

  const nodes = [
    // Memory/Infra
    { id: "beads",       x: 50,  y: 200, label: "Beads",       sub: "Task memory",       color: COLORS.accent2, layer: "memory" },
    { id: "dolt",        x: 50,  y: 310, label: "Dolt",        sub: "Version-ctrl DB",   color: COLORS.accent2, layer: "memory" },
    // Orchestrators
    { id: "gastown",     x: 220, y: 120, label: "Gastown",     sub: "Fleet orchestrator",color: COLORS.accent1, layer: "orch" },
    { id: "composio",    x: 220, y: 260, label: "Composio AO", sub: "Parallel harness",  color: COLORS.accent1, layer: "orch" },
    { id: "mastra",      x: 220, y: 390, label: "Mastra",      sub: "TS app framework",  color: COLORS.accent1, layer: "orch" },
    // Methodology
    { id: "superpowers", x: 400, y: 80,  label: "Superpowers", sub: "TDD methodology",   color: COLORS.accent3, layer: "method" },
    { id: "gstack",      x: 400, y: 200, label: "GStack",      sub: "Role personas",     color: COLORS.accent3, layer: "method" },
    { id: "babysitter",  x: 400, y: 320, label: "Babysitter",  sub: "Deterministic proc",color: COLORS.accent3, layer: "method" },
    // Interface
    { id: "openclaw",    x: 580, y: 140, label: "OpenClaw",    sub: "Messaging gateway", color: COLORS.accent6, layer: "interface" },
    { id: "dorothy",     x: 580, y: 260, label: "Dorothy",     sub: "Desktop GUI",       color: COLORS.accent6, layer: "interface" },
    // Protocol
    { id: "mcp",         x: 400, y: 450, label: "MCP",         sub: "Tool protocol",     color: COLORS.accent5, layer: "tools" },
    { id: "skillmd",     x: 580, y: 390, label: "SKILL.md",    sub: "Cross-platform std",color: COLORS.accent5, layer: "tools" },
  ];

  const edges = [
    // Real existing connections
    { from: "gastown", to: "beads",       type: "uses",    label: "task tracking",  real: true },
    { from: "gastown", to: "dolt",        type: "uses",    label: "mail + state",   real: true },
    { from: "gastown", to: "superpowers", type: "compat",  label: "can layer on",   real: false },
    { from: "composio", to: "mcp",        type: "uses",    label: "tool protocol",  real: true },
    { from: "mastra",  to: "mcp",         type: "uses",    label: "tool compat",    real: true },
    { from: "mastra",  to: "skillmd",     type: "compat",  label: "could adopt",    real: false },
    { from: "openclaw", to: "skillmd",    type: "uses",    label: "skill system",   real: true },
    { from: "gstack",  to: "skillmd",     type: "uses",    label: "skill system",   real: true },
    { from: "superpowers", to: "skillmd", type: "uses",    label: "is a SKILL.md",  real: true },
    { from: "babysitter", to: "mcp",      type: "compat",  label: "planned",        real: false },
    { from: "dorothy", to: "composio",    type: "compat",  label: "could wrap",     real: false },
    { from: "dorothy", to: "gastown",     type: "compat",  label: "could wrap",     real: false },
    { from: "openclaw", to: "mastra",     type: "missing", label: "no bridge",      real: false },
    { from: "beads",   to: "mastra",      type: "missing", label: "no bridge",      real: false },
    { from: "babysitter", to: "gastown",  type: "missing", label: "no bridge",      real: false },
    { from: "superpowers", to: "babysitter", type: "compat", label: "methodology stack", real: false },
  ];

  const nodeMap = Object.fromEntries(nodes.map(n => [n.id, n]));
  const W = 700, H = 520;

  const getEdgeColor = (type) => {
    if (type === "uses") return COLORS.accent2;
    if (type === "compat") return COLORS.accent3 + "aa";
    if (type === "missing") return COLORS.accent4 + "88";
    return COLORS.border;
  };
  const getEdgeDash = (type) => {
    if (type === "uses") return "none";
    if (type === "compat") return "6,4";
    if (type === "missing") return "3,4";
    return "none";
  };

  const relEdges = activeNode
    ? edges.filter(e => e.from === activeNode || e.to === activeNode)
    : edges;

  return (
    <div style={{ padding: "32px 24px" }}>
      <h2 style={{ color: COLORS.text, fontFamily: "'Georgia', serif", fontSize: 22, marginBottom: 8, fontWeight: 400 }}>
        Framework Connection Graph
      </h2>
      <div style={{ display: "flex", gap: 20, marginBottom: 20, flexWrap: "wrap" }}>
        {[
          { color: COLORS.accent2, dash: false, label: "Real existing connection" },
          { color: COLORS.accent3, dash: true,  label: "Could connect / compatible" },
          { color: COLORS.accent4, dash: true,  label: "Missing bridge — gap" },
        ].map(l => (
          <div key={l.label} style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <svg width={40} height={12}>
              <line x1={0} y1={6} x2={40} y2={6}
                stroke={l.color} strokeWidth={2}
                strokeDasharray={l.dash ? "5,3" : "none"} />
            </svg>
            <span style={{ color: COLORS.textDim, fontSize: 11 }}>{l.label}</span>
          </div>
        ))}
      </div>
      <p style={{ color: COLORS.textDim, fontSize: 12, marginBottom: 16 }}>Click a node to highlight its connections.</p>

      <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ background: COLORS.surface, borderRadius: 10, border: `1px solid ${COLORS.border}` }}>
        {/* Layer bands */}
        {[
          { x: 10,  w: 130, label: "MEMORY", color: COLORS.accent2 },
          { x: 150, w: 140, label: "ORCHESTRATION", color: COLORS.accent1 },
          { x: 310, w: 160, label: "METHODOLOGY", color: COLORS.accent3 },
          { x: 490, w: 200, label: "INTERFACE + TOOLS", color: COLORS.accent5 },
        ].map(b => (
          <g key={b.label}>
            <rect x={b.x} y={10} width={b.w} height={H - 20} rx={6}
              fill={b.color + "08"} stroke={b.color + "22"} strokeWidth={1} />
            <text x={b.x + b.w / 2} y={26} textAnchor="middle"
              fill={b.color + "66"} fontSize={8} letterSpacing={2} fontFamily="monospace">
              {b.label}
            </text>
          </g>
        ))}

        {/* Edges */}
        {edges.map((e, i) => {
          const a = nodeMap[e.from], b = nodeMap[e.to];
          if (!a || !b) return null;
          const isActive = !activeNode || relEdges.includes(e);
          const opacity = activeNode ? (isActive ? 1 : 0.08) : 0.7;
          const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
          return (
            <g key={i} opacity={opacity}>
              <line x1={a.x} y1={a.y} x2={b.x} y2={b.y}
                stroke={getEdgeColor(e.type)}
                strokeWidth={isActive ? 1.5 : 1}
                strokeDasharray={getEdgeDash(e.type)} />
              {isActive && (
                <text x={mx} y={my - 4} textAnchor="middle"
                  fill={getEdgeColor(e.type)} fontSize={8} fontFamily="monospace" opacity={0.8}>
                  {e.label}
                </text>
              )}
            </g>
          );
        })}

        {/* Nodes */}
        {nodes.map(n => {
          const isActive = !activeNode || activeNode === n.id ||
            relEdges.some(e => e.from === n.id || e.to === n.id);
          return (
            <g key={n.id} onClick={() => setActiveNode(activeNode === n.id ? null : n.id)}
              style={{ cursor: "pointer" }} opacity={activeNode ? (isActive ? 1 : 0.2) : 1}>
              <circle cx={n.x} cy={n.y} r={36} fill={n.color + "18"}
                stroke={activeNode === n.id ? n.color : n.color + "55"}
                strokeWidth={activeNode === n.id ? 2 : 1} />
              <text x={n.x} y={n.y - 5} textAnchor="middle"
                fill={n.color} fontSize={11} fontWeight="600" fontFamily="'Georgia', serif">
                {n.label}
              </text>
              <text x={n.x} y={n.y + 9} textAnchor="middle"
                fill={n.color + "99"} fontSize={8} fontFamily="monospace">
                {n.sub}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}

// ─── DATA FLOW ────────────────────────────────────────────────────────────────
function DataFlow() {
  const [activeFlow, setActiveFlow] = useState("task");

  const flows = {
    task: {
      label: "Task Lifecycle",
      color: COLORS.accent1,
      steps: [
        { actor: "Human / Trigger",   action: "Issue created or message received",                system: "GitHub / WhatsApp / CLI",    color: COLORS.accent6 },
        { actor: "Interface Layer",   action: "Normalize inbound to common format",               system: "OpenClaw / Dorothy / AO",    color: COLORS.accent6 },
        { actor: "Orchestrator",      action: "Decompose into atomic work items (beads)",         system: "Gastown Mayor / Babysitter", color: COLORS.accent1 },
        { actor: "Skill Lookup",      action: "Match methodology to task type",                   system: "SKILL.md / Process Library", color: COLORS.accent3 },
        { actor: "Agent Dispatch",    action: "Spawn worker in isolated worktree",                system: "Polecat / Composio Worker",  color: COLORS.accent4 },
        { actor: "Agent Execution",   action: "Run TDD cycle: RED→GREEN→REFACTOR→commit",        system: "Claude Code / Codex",        color: COLORS.accent4 },
        { actor: "Quality Gate",      action: "CI, coverage, lint, security scan",               system: "Babysitter / Composio CI",   color: COLORS.accent3 },
        { actor: "Review",            action: "Spec compliance + code quality (dual review)",    system: "Superpowers reviewers",      color: COLORS.accent3 },
        { actor: "Memory Write",      action: "Close bead, update task graph, persist learnings",system: "Beads / Mastra Memory",      color: COLORS.accent2 },
        { actor: "Merge",             action: "Refinery processes PR, resolves conflicts",       system: "Gastown Refinery",           color: COLORS.accent1 },
        { actor: "Human Checkpoint",  action: "Optional approval gate before ship",              system: "Breakpoints / Composio UI",  color: COLORS.accent6 },
      ],
    },
    memory: {
      label: "Memory Read/Write",
      color: COLORS.accent2,
      steps: [
        { actor: "Session Start",     action: "Load MEMORY.md + daily logs + SKILL.md bootstrap",system: "OpenClaw / Superpowers",    color: COLORS.accent6 },
        { actor: "Working Memory",    action: "Context window — session-scoped, all tools see it",system: "LLM context",              color: COLORS.accent2 },
        { actor: "Task Read",         action: "bd ready → unblocked tasks, topologically sorted", system: "Beads CLI",                color: COLORS.accent2 },
        { actor: "Agent Claims Task", action: "bd update --claim → atomic lock",                  system: "Beads / Dolt",             color: COLORS.accent2 },
        { actor: "Execution",         action: "Agent works, uses context window + tools",         system: "Any agent runtime",        color: COLORS.accent4 },
        { actor: "Compaction",        action: "Observer LLM summarizes old turns in background",  system: "Mastra Observational",     color: COLORS.accent2 },
        { actor: "Task Close",        action: "bd close + reason → frees dependents",             system: "Beads",                   color: COLORS.accent2 },
        { actor: "Long-term Write",   action: "Curate lessons → MEMORY.md or semantic vector DB", system: "OpenClaw / Mastra",        color: COLORS.accent2 },
        { actor: "Cross-session",     action: "Next session loads compacted + curated memory",    system: "All frameworks (silo'd)",  color: COLORS.accent2 },
      ],
    },
    routing: {
      label: "Model & Agent Routing",
      color: COLORS.accent3,
      steps: [
        { actor: "Task Arrives",      action: "With metadata: type, complexity, cost tier",      system: "Orchestrator",              color: COLORS.accent1 },
        { actor: "Complexity Score",  action: "Classify: creative / analytical / mechanical",    system: "Router (no standard yet)",  color: COLORS.accent3 },
        { actor: "Provider Select",   action: "Claude for reasoning, Haiku for sub-agents, local for bulk", system: "LiteLLM / Mastra model router", color: COLORS.accent3 },
        { actor: "Agent Select",      action: "Claude Code / Codex / Aider / Gemini CLI by capability", system: "Gastown presets / Composio slots", color: COLORS.accent4 },
        { actor: "Budget Check",      action: "Is remaining budget sufficient?",                 system: "⚠ NO FRAMEWORK HAS THIS",   color: "#f76e6e" },
        { actor: "Fallback",          action: "If primary fails → retry with next provider",     system: "LiteLLM cooldowns (ext.)",  color: COLORS.accent3 },
        { actor: "A/B Attribution",   action: "Log model+agent → task outcome for future routing",system: "Gastown built-in, others ❌", color: COLORS.accent3 },
      ],
    },
  };

  const f = flows[activeFlow];

  return (
    <div style={{ padding: "32px 24px" }}>
      <h2 style={{ color: COLORS.text, fontFamily: "'Georgia', serif", fontSize: 22, marginBottom: 8, fontWeight: 400 }}>
        Data & State Flow
      </h2>
      <p style={{ color: COLORS.textDim, fontSize: 13, marginBottom: 20 }}>
        How state moves through the system across different scenarios.
      </p>

      <div style={{ display: "flex", gap: 8, marginBottom: 28 }}>
        {Object.entries(flows).map(([k, v]) => (
          <button key={k} onClick={() => setActiveFlow(k)} style={{
            background: activeFlow === k ? v.color + "22" : "transparent",
            border: `1px solid ${activeFlow === k ? v.color : COLORS.border}`,
            borderRadius: 6, padding: "6px 14px",
            color: activeFlow === k ? v.color : COLORS.textDim,
            fontSize: 12, cursor: "pointer", fontFamily: "inherit",
          }}>
            {v.label}
          </button>
        ))}
      </div>

      <div style={{ position: "relative" }}>
        {/* Vertical spine */}
        <div style={{
          position: "absolute", left: 155, top: 20, bottom: 20,
          width: 2, background: `linear-gradient(to bottom, transparent, ${f.color}44, transparent)`,
        }} />

        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {f.steps.map((step, i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 0 }}>
              {/* Step number */}
              <div style={{
                width: 28, height: 28, borderRadius: "50%",
                background: step.color + "22", border: `1px solid ${step.color}55`,
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 10, color: step.color, fontFamily: "monospace",
                flexShrink: 0, marginRight: 12,
              }}>{String(i + 1).padStart(2, "0")}</div>

              {/* Actor */}
              <div style={{ width: 140, flexShrink: 0, textAlign: "right", paddingRight: 20 }}>
                <span style={{ color: step.color, fontSize: 11, fontWeight: 600 }}>{step.actor}</span>
              </div>

              {/* Node on spine */}
              <div style={{
                width: 12, height: 12, borderRadius: "50%",
                background: step.color, flexShrink: 0, zIndex: 1,
                marginLeft: -1,
              }} />

              {/* Action + system */}
              <div style={{
                flex: 1, marginLeft: 16,
                background: COLORS.surface,
                border: `1px solid ${step.color}22`,
                borderRadius: 6, padding: "8px 12px",
              }}>
                <div style={{ color: COLORS.text, fontSize: 12, marginBottom: 3 }}>{step.action}</div>
                <div style={{ color: step.color + "88", fontSize: 10, fontFamily: "monospace" }}>{step.system}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── GAPS ─────────────────────────────────────────────────────────────────────
function GapsMap() {
  const gaps = [
    {
      severity: "critical",
      title: "No Shared Memory Across Frameworks",
      detail: "Mastra agents can't read Beads task graphs. OpenClaw MEMORY.md is invisible to Gastown. Each framework is a memory silo. A task completed in Composio AO leaves no trace Mastra can query.",
      affects: ["All frameworks"],
      fix: "Unified memory bus: standardized event schema + adapter layer. Beads' hash IDs + Mastra's semantic recall + OpenClaw's daily logs need a common read interface.",
    },
    {
      severity: "critical",
      title: "No Cost-Aware Routing",
      detail: "No framework tracks real-time spend and routes accordingly. Gastown users report $100/hour burn rates. No circuit breaker exists that says 'switch to Haiku, budget exhausted for today.'",
      affects: ["Gastown", "OpenClaw", "Composio AO"],
      fix: "Budget middleware layer: per-task cost estimate → running total → model downgrade triggers → hard kill switch.",
    },
    {
      severity: "critical",
      title: "No Cross-Agent Discovery",
      detail: "A Claude Code agent managed by Gastown cannot see, message, or delegate to an OpenCode agent in a Composio session. There is no agent registry or A2A protocol below the human operator layer.",
      affects: ["Gastown", "Composio AO", "OpenClaw", "Mastra"],
      fix: "Agent registry with standardized A2A protocol (Pilot Protocol's approach is the right direction). Each agent registers with capabilities, status, model, and current workload.",
    },
    {
      severity: "high",
      title: "No Process Composition",
      detail: "You can't combine Superpowers TDD + Babysitter BDD in one pipeline. GStack personas can't invoke a Babysitter process. Methodology layers are siloed just like memory.",
      affects: ["Superpowers", "Babysitter", "GStack"],
      fix: "Process composition protocol: each methodology exposes named stages with defined I/O. An orchestrator assembles them like middleware.",
    },
    {
      severity: "high",
      title: "Skill Sandbox Security is Broken",
      detail: "OpenClaw's ClawHub: 26% CVE rate in audited skills. 230+ malicious skills uploaded in the first week. CVE-2026-25253 enabled RCE on 21,000+ exposed instances. No framework has a sandboxed execution model for skills.",
      affects: ["OpenClaw / ClawHub"],
      fix: "WASM-sandboxed skill execution. Permission manifest per skill. Code signing. Review pipeline before publication. Superpowers' markdown-only skills partially mitigate this — instructions can't exec arbitrary code.",
    },
    {
      severity: "high",
      title: "No Deferred Tool Loading Standard",
      detail: "Superpowers loads all 14 skills at startup (~22K tokens, 11% of context). Most frameworks bulk-load all tool schemas. Anthropic's Tool Search Tool proves deferred loading reduces token usage 85% while improving accuracy. No framework implements this consistently.",
      affects: ["Superpowers", "OpenClaw", "GStack"],
      fix: "Progressive disclosure: compact metadata (~100 tokens) at boot, full schema on activation, resources on execution. Already standard in SKILL.md spec — not implemented.",
    },
    {
      severity: "medium",
      title: "Human-in-Loop is Optional Everywhere (Except Babysitter)",
      detail: "Composio AO auto-merges on CI green. Gastown auto-merges even with failing CI (caused a hard reset for DoltHub team). Only Babysitter enforces breakpoints as non-optional code gates. Superpowers plan reviews can be skipped.",
      affects: ["Gastown", "Composio AO", "Superpowers"],
      fix: "Enforce breakpoints in the orchestration layer, not as methodology suggestions. Babysitter's `ctx.breakpoint()` pattern should be a first-class primitive in every orchestrator.",
    },
    {
      severity: "medium",
      title: "No Observability Standard",
      detail: "Mastra has OpenTelemetry-native traces across 16 platforms. OpenClaw has grep-able flat files. Gastown has tmux panes. Composio has a Next.js dashboard. Babysitter has journal replay. No cross-framework trace that follows a task from intake to merge.",
      affects: ["All frameworks"],
      fix: "OpenTelemetry as the standard. Each framework emits spans with a correlation ID that persists across agent handoffs. Distributed traces, not local dashboards.",
    },
    {
      severity: "medium",
      title: "No Multi-Human Collaboration",
      detail: "All frameworks assume one human operator (Gastown's 'Overseer'). No access control, no concurrent operator support, no task assignment between humans, no role-based permissions on what agents can do.",
      affects: ["All frameworks"],
      fix: "Multi-tenancy layer: user identities, RBAC on agent capabilities, task ownership, audit logs per operator.",
    },
    {
      severity: "low",
      title: "Subagent Context Injection is Unreliable",
      detail: "Superpowers subagents may not receive the using-superpowers bootstrap. OpenClaw sub-agents get UUID addresses but not meaningful capability descriptions. Agents spawned by other agents often lose methodology context.",
      affects: ["Superpowers", "OpenClaw"],
      fix: "Inherit context protocol: when spawning a subagent, explicitly pass methodology context, memory snapshot, and tool registry slice relevant to the subtask.",
    },
  ];

  const sevColor = { critical: "#f76e6e", high: "#f7a06e", medium: "#f7c04a", low: COLORS.accent5 };
  const sevLabel = { critical: "CRITICAL", high: "HIGH", medium: "MEDIUM", low: "LOW" };

  return (
    <div style={{ padding: "32px 24px" }}>
      <h2 style={{ color: COLORS.text, fontFamily: "'Georgia', serif", fontSize: 22, marginBottom: 8, fontWeight: 400 }}>
        What's Missing — Gap Analysis
      </h2>
      <p style={{ color: COLORS.textDim, fontSize: 13, marginBottom: 28 }}>
        Ten structural gaps across the eight frameworks. This is where your orchestrator can win.
      </p>

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {gaps.map((g, i) => (
          <div key={i} style={{
            background: COLORS.surface, border: `1px solid ${COLORS.border}`,
            borderLeft: `3px solid ${sevColor[g.severity]}`,
            borderRadius: 8, padding: "16px 20px",
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 8 }}>
              <span style={{
                background: sevColor[g.severity] + "22",
                color: sevColor[g.severity],
                fontSize: 9, fontFamily: "monospace", letterSpacing: 1,
                padding: "2px 7px", borderRadius: 4,
              }}>{sevLabel[g.severity]}</span>
              <span style={{ color: COLORS.text, fontSize: 14, fontWeight: 600 }}>{g.title}</span>
            </div>

            <p style={{ color: COLORS.textDim, fontSize: 12, lineHeight: 1.6, margin: "0 0 10px" }}>{g.detail}</p>

            <div style={{ display: "flex", gap: 6, flexWrap: "wrap", marginBottom: 10 }}>
              {g.affects.map(a => (
                <span key={a} style={{
                  background: COLORS.surface2, border: `1px solid ${COLORS.border}`,
                  borderRadius: 4, padding: "2px 8px",
                  color: COLORS.textDim, fontSize: 10, fontFamily: "monospace",
                }}>{a}</span>
              ))}
            </div>

            <div style={{
              background: COLORS.accent5 + "0d", border: `1px solid ${COLORS.accent5}22`,
              borderRadius: 6, padding: "8px 12px",
            }}>
              <span style={{ color: COLORS.accent5, fontSize: 10, fontWeight: 600, letterSpacing: 1 }}>FIX → </span>
              <span style={{ color: COLORS.accent5 + "cc", fontSize: 11 }}>{g.fix}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── IDEAL ORCHESTRATOR ───────────────────────────────────────────────────────
function IdealOrchestrator() {
  const [activeZone, setActiveZone] = useState(null);

  const zones = [
    {
      id: "ingest",
      label: "01 Ingest & Normalize",
      color: COLORS.accent6,
      pos: { x: 10, y: 10, w: 680, h: 60 },
      components: [
        "Channel adapters (messaging, web, CLI, API, file watch)",
        "Unified event schema (source, actor, intent, priority, budget)",
        "Dedup + idempotency keys",
        "Cost ceiling injection",
      ],
      stolen: "OpenClaw channel adapters + Babysitter event schema",
    },
    {
      id: "router",
      label: "02 Intent Router",
      color: COLORS.accent1,
      pos: { x: 10, y: 82, w: 330, h: 130 },
      components: [
        "Task classifier: creative / analytical / mechanical / review",
        "Complexity scorer → model tier selection",
        "Budget-aware provider fallback chain",
        "A/B routing with outcome attribution",
        "Human-in-loop trigger conditions",
      ],
      stolen: "Gastown cost tiers + Mastra model router + LiteLLM fallbacks",
    },
    {
      id: "process",
      label: "03 Process Selector",
      color: COLORS.accent3,
      pos: { x: 352, y: 82, w: 338, h: 130 },
      components: [
        "Methodology registry (SKILL.md + Babysitter processes)",
        "Process composition: chain TDD + BDD + review phases",
        "Persona assignment (GStack-style role injection)",
        "Progressive skill disclosure (deferred loading)",
      ],
      stolen: "Superpowers SKILL.md + Babysitter process library + GStack personas",
    },
    {
      id: "memory",
      label: "04 Memory Bus",
      color: COLORS.accent2,
      pos: { x: 10, y: 224, w: 220, h: 220 },
      components: [
        "Working: context window (session-scoped)",
        "Episodic: JSONL event journal (crash-safe)",
        "Semantic: vector search (cross-session recall)",
        "Procedural: task graph (Beads-style hash IDs)",
        "Observational compaction (background LLM)",
        "Unified read interface for all agents",
      ],
      stolen: "Mastra 3-layer + Beads task graph + Babysitter journal + OpenClaw daily logs",
    },
    {
      id: "fleet",
      label: "05 Fleet Manager",
      color: COLORS.accent1,
      pos: { x: 242, y: 224, w: 218, h: 220 },
      components: [
        "Agent registry: capabilities, status, model, load",
        "Worktree isolation per task",
        "Spawn / kill / restart with circuit breaker",
        "Convoy / batch tracking (Gastown-style)",
        "Context handoff protocol (GUPP-inspired)",
        "Séance: new session resumes old via hook",
      ],
      stolen: "Gastown Mayor/Polecats + Composio 8-slot plugins + OpenClaw sub-agents",
    },
    {
      id: "quality",
      label: "06 Quality Gates",
      color: COLORS.accent3,
      pos: { x: 472, y: 224, w: 218, h: 220 },
      components: [
        "CI integration: auto-feed failures back to agent",
        "Code gates: coverage, lint, security, type-check",
        "Dual LLM review: spec compliance + code quality",
        "Convergent loops: iterate until gates pass",
        "Cryptographic completion proof",
        "Enforced breakpoints (non-optional)",
      ],
      stolen: "Babysitter gates + Composio CI reactions + Superpowers dual-review",
    },
    {
      id: "observability",
      label: "07 Observability",
      color: COLORS.accent5,
      pos: { x: 10, y: 456, w: 330, h: 80 },
      components: [
        "OpenTelemetry spans with correlation ID across all agent hops",
        "Cost tracking per task, per agent, per model, per session",
        "Dashboard: live fleet view + kanban + terminal embed",
        "Audit log: who triggered what, when, with what outcome",
      ],
      stolen: "Mastra OTel (16 platforms) + Composio dashboard + Babysitter journal replay",
    },
    {
      id: "security",
      label: "08 Security & Governance",
      color: "#f76e6e",
      pos: { x: 352, y: 456, w: 338, h: 80 },
      components: [
        "WASM-sandboxed skill execution",
        "RBAC: operator identities, agent capability limits",
        "Network allow-lists per agent runtime",
        "Signed skill manifests (no ClawHub-style open publish)",
        "Ed25519 agent identity (Pilot Protocol approach)",
      ],
      stolen: "MS Agent Governance Toolkit + Greywall sandboxing + Pilot Protocol identity",
    },
  ];

  const activeZoneData = zones.find(z => z.id === activeZone);
  const SVG_W = 700, SVG_H = 550;

  return (
    <div style={{ padding: "32px 24px" }}>
      <h2 style={{ color: COLORS.text, fontFamily: "'Georgia', serif", fontSize: 22, marginBottom: 8, fontWeight: 400 }}>
        The Ideal Orchestrator Blueprint
      </h2>
      <p style={{ color: COLORS.textDim, fontSize: 13, marginBottom: 8, lineHeight: 1.6 }}>
        Eight zones assembled from the best of every framework — without their individual blind spots.
        Click any zone to see what it steals from existing frameworks and what it adds.
      </p>

      <div style={{ display: "flex", gap: 24, alignItems: "flex-start" }}>
        <svg viewBox={`0 0 ${SVG_W} ${SVG_H}`} style={{
          background: COLORS.surface, borderRadius: 10,
          border: `1px solid ${COLORS.border}`,
          flex: "0 0 auto", width: "min(100%, 520px)",
        }}>
          {zones.map(z => (
            <g key={z.id} onClick={() => setActiveZone(activeZone === z.id ? null : z.id)}
              style={{ cursor: "pointer" }}>
              <rect
                x={z.pos.x + 4} y={z.pos.y + 4}
                width={z.pos.w - 8} height={z.pos.h - 8}
                rx={8}
                fill={activeZone === z.id ? z.color + "28" : z.color + "10"}
                stroke={activeZone === z.id ? z.color : z.color + "44"}
                strokeWidth={activeZone === z.id ? 2 : 1}
              />
              <text
                x={z.pos.x + z.pos.w / 2}
                y={z.pos.y + z.pos.h / 2 - 4}
                textAnchor="middle"
                fill={z.color}
                fontSize={11}
                fontWeight="700"
                fontFamily="monospace"
                letterSpacing={0.5}
              >
                {z.label}
              </text>
              <text
                x={z.pos.x + z.pos.w / 2}
                y={z.pos.y + z.pos.h / 2 + 12}
                textAnchor="middle"
                fill={z.color + "77"}
                fontSize={8}
                fontFamily="monospace"
              >
                {z.components.length} components — click to expand
              </text>
            </g>
          ))}

          {/* Flow arrows */}
          {[
            // Ingest → Router
            { x1: 170, y1: 70, x2: 170, y2: 82, color: COLORS.accent6 },
            // Ingest → Process
            { x1: 520, y1: 70, x2: 520, y2: 82, color: COLORS.accent6 },
            // Router → Fleet
            { x1: 175, y1: 212, x2: 310, y2: 224, color: COLORS.accent1 },
            // Process → Fleet
            { x1: 520, y1: 212, x2: 390, y2: 224, color: COLORS.accent3 },
            // Memory ↔ Fleet
            { x1: 230, y1: 334, x2: 242, y2: 334, color: COLORS.accent2 },
            // Fleet → Quality
            { x1: 460, y1: 334, x2: 472, y2: 334, color: COLORS.accent1 },
            // Fleet → Observability
            { x1: 310, y1: 444, x2: 220, y2: 456, color: COLORS.accent1 },
            // Quality → Observability
            { x1: 520, y1: 444, x2: 490, y2: 456, color: COLORS.accent3 },
          ].map((a, i) => (
            <g key={i}>
              <line x1={a.x1} y1={a.y1} x2={a.x2} y2={a.y2}
                stroke={a.color + "66"} strokeWidth={1.5}
                strokeDasharray="3,3" />
            </g>
          ))}
        </svg>

        {/* Detail panel */}
        <div style={{
          flex: 1, minWidth: 200,
          background: COLORS.surface,
          border: `1px solid ${activeZoneData ? activeZoneData.color + "44" : COLORS.border}`,
          borderRadius: 10, padding: 20,
          minHeight: 300,
          transition: "border-color 0.2s",
        }}>
          {activeZoneData ? (
            <>
              <div style={{ color: activeZoneData.color, fontSize: 13, fontWeight: 700, marginBottom: 16, fontFamily: "monospace" }}>
                {activeZoneData.label}
              </div>
              <div style={{ marginBottom: 16 }}>
                <div style={{ color: COLORS.textDim, fontSize: 10, letterSpacing: 1, marginBottom: 8, textTransform: "uppercase" }}>Components</div>
                {activeZoneData.components.map((c, i) => (
                  <div key={i} style={{ display: "flex", gap: 8, marginBottom: 6 }}>
                    <span style={{ color: activeZoneData.color, fontSize: 10, marginTop: 2 }}>▸</span>
                    <span style={{ color: COLORS.text, fontSize: 12, lineHeight: 1.5 }}>{c}</span>
                  </div>
                ))}
              </div>
              <div style={{
                background: activeZoneData.color + "0e",
                border: `1px solid ${activeZoneData.color}22`,
                borderRadius: 6, padding: "10px 12px",
              }}>
                <div style={{ color: activeZoneData.color, fontSize: 10, letterSpacing: 1, marginBottom: 6, textTransform: "uppercase" }}>Stolen From</div>
                <div style={{ color: activeZoneData.color + "cc", fontSize: 11, lineHeight: 1.5 }}>{activeZoneData.stolen}</div>
              </div>
            </>
          ) : (
            <div style={{ color: COLORS.textFaint, fontSize: 13, lineHeight: 1.8, paddingTop: 20 }}>
              Click any zone in the blueprint to see its components and which existing frameworks it draws from.
              <br /><br />
              The ideal orchestrator doesn't invent new ideas — it assembles the best parts of what already exists and fills the gaps that none of them cover.
            </div>
          )}
        </div>
      </div>

      {/* Principles */}
      <div style={{ marginTop: 24, display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 10 }}>
        {[
          { principle: "Code is authority", detail: "Babysitter's core insight: JS function controls flow, not LLM improvisation" },
          { principle: "Memory is shared", detail: "Unified bus bridges Beads, Mastra, OpenClaw silos via adapter interface" },
          { principle: "Skills are disclosed progressively", detail: "Metadata at boot, full content on activation — never bulk-load" },
          { principle: "Gates are enforced, not suggested", detail: "Breakpoints block. CI failures re-enter the agent. No auto-merge on red." },
          { principle: "Cost is a first-class primitive", detail: "Every route decision weighs remaining budget. Hard kills before overspend." },
          { principle: "Agents are discoverable", detail: "Registry with A2A protocol. Agents can find and delegate to each other." },
          { principle: "Traces follow tasks, not sessions", detail: "One correlation ID from ingest through merge — spans all agent hops." },
          { principle: "Skills are sandboxed", detail: "WASM execution, signed manifests, permission-scoped — not open-publish." },
        ].map((p, i) => (
          <div key={i} style={{
            background: COLORS.surface, border: `1px solid ${COLORS.border}`,
            borderRadius: 8, padding: "12px 14px",
          }}>
            <div style={{ color: COLORS.text, fontSize: 12, fontWeight: 600, marginBottom: 4 }}>{p.principle}</div>
            <div style={{ color: COLORS.textDim, fontSize: 11, lineHeight: 1.5 }}>{p.detail}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── ROOT ─────────────────────────────────────────────────────────────────────
export default function App() {
  const [activeTab, setActiveTab] = useState("layers");

  const panels = {
    layers: <LayerMap />,
    connections: <ConnectionGraph />,
    dataflow: <DataFlow />,
    gaps: <GapsMap />,
    orchestrator: <IdealOrchestrator />,
  };

  return (
    <div style={{ background: COLORS.bg, minHeight: "100vh", fontFamily: "'Georgia', serif", color: COLORS.text }}>
      {/* Header */}
      <div style={{
        borderBottom: `1px solid ${COLORS.border}`,
        padding: "20px 24px 0",
        background: COLORS.surface,
      }}>
        <div style={{ fontSize: 11, color: COLORS.textFaint, letterSpacing: 3, fontFamily: "monospace", marginBottom: 6 }}>
          AGENTIC FRAMEWORK ANALYSIS
        </div>
        <h1 style={{ margin: "0 0 16px", fontSize: 20, fontWeight: 400, color: COLORS.text, lineHeight: 1.3 }}>
          Eight Frameworks, One Blueprint
        </h1>
        <div style={{ display: "flex", gap: 4, overflowX: "auto" }}>
          {tabs.map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              background: activeTab === t.id ? COLORS.accent1 + "22" : "transparent",
              border: "none",
              borderBottom: `2px solid ${activeTab === t.id ? COLORS.accent1 : "transparent"}`,
              borderRadius: "6px 6px 0 0",
              padding: "8px 16px",
              color: activeTab === t.id ? COLORS.accent1 : COLORS.textDim,
              fontSize: 12, cursor: "pointer", fontFamily: "inherit",
              whiteSpace: "nowrap",
              transition: "all 0.15s",
            }}>
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {/* Panel */}
      <div style={{ maxWidth: 900, margin: "0 auto" }}>
        {panels[activeTab]}
      </div>
    </div>
  );
}
