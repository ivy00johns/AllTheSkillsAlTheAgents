import { useState, useEffect, useRef } from "react";

/* ─── DESIGN TOKENS ─────────────────────────────────────── */
const T = {
  // Amber/honey palette
  honey:    "#f5a623",
  honeyDim: "#c4821a",
  amber:    "#ff8c00",
  gold:     "#ffd166",
  cream:    "#fff8e7",
  // Dark hive
  void:     "#060608",
  hive:     "#0d0d10",
  cell:     "#141418",
  wall:     "#1e1e26",
  border:   "#2a2a38",
  // Semantic
  queen:    "#c084fc",
  worker:   "#34d399",
  brood:    "#60a5fa",
  sting:    "#f87171",
  signal:   "#fbbf24",
  // Text
  text:     "#eeeef5",
  textDim:  "#7878a0",
  textFaint:"#3a3a52",
};

/* ─── SHARED ATOMS ──────────────────────────────────────── */
const Badge = ({ color, children, small }) => (
  <span style={{
    display:"inline-block",
    background: color + "20",
    border: `1px solid ${color}50`,
    borderRadius: 4,
    padding: small ? "1px 5px" : "2px 8px",
    color, fontSize: small ? 9 : 10,
    fontFamily:"'Courier New',monospace",
    letterSpacing: 1,
    whiteSpace:"nowrap",
  }}>{children}</span>
);

const Dot = ({ color, pulse }) => (
  <span style={{
    display:"inline-block", width:8, height:8, borderRadius:"50%",
    background: color,
    boxShadow: pulse ? `0 0 0 3px ${color}30` : "none",
    animation: pulse ? "pulseRing 2s infinite" : "none",
  }}/>
);

const HexCell = ({ filled, color, size=24 }) => {
  const s = size, h = s * 0.866;
  return (
    <svg width={s} height={h} viewBox={`0 0 ${s} ${h}`}>
      <polygon
        points={`${s/2},0 ${s},${h*0.25} ${s},${h*0.75} ${s/2},${h} 0,${h*0.75} 0,${h*0.25}`}
        fill={filled ? color + "40" : "transparent"}
        stroke={color || T.border}
        strokeWidth={1}
      />
    </svg>
  );
};

/* ─── SCREEN DEFINITIONS ────────────────────────────────── */
const screens = [
  { id:"yard",      label:"01 · The Yard", sub:"Fleet overview" },
  { id:"glass",     label:"02 · The Glass", sub:"Observation view" },
  { id:"comb",      label:"03 · The Comb", sub:"Shared memory / task graph" },
  { id:"worker",    label:"04 · Worker Detail", sub:"Single agent deep-dive" },
  { id:"waggle",    label:"05 · The Waggle", sub:"Skill / tool registry" },
  { id:"keeper",    label:"06 · The Keeper", sub:"Human-in-the-loop approvals" },
  { id:"smoker",    label:"07 · The Smoker", sub:"CLI web bridge" },
  { id:"trail",     label:"08 · The Trail", sub:"Trace / observability view" },
  { id:"yield",     label:"09 · The Yield", sub:"Metrics & cost dashboard" },
  { id:"queen",     label:"10 · The Queen", sub:"Orchestrator control plane" },
];

/* ═══════════════════════════════════════════════════════
   SCREEN 01 — THE YARD (Fleet Overview)
═══════════════════════════════════════════════════════ */
function ScreenYard() {
  const [tick, setTick] = useState(0);
  useEffect(() => { const t = setInterval(() => setTick(v=>v+1),1800); return ()=>clearInterval(t); },[]);

  const workers = [
    { id:"w-01", name:"auth-refactor",   model:"claude-opus",   status:"running", progress:72, task:"Writing tests for OAuth flow",     cost:"$2.14", cells:12 },
    { id:"w-02", name:"ui-components",   model:"claude-sonnet", status:"running", progress:38, task:"Generating Button component variants",cost:"$0.87", cells:6 },
    { id:"w-03", name:"api-integration", model:"claude-opus",   status:"capped",  progress:100,task:"Awaiting keeper approval",          cost:"$4.20", cells:18 },
    { id:"w-04", name:"db-migrations",   model:"codex",         status:"running", progress:55, task:"Running migration on dev schema",   cost:"$1.33", cells:9 },
    { id:"w-05", name:"security-audit",  model:"claude-opus",   status:"stinging",progress:20, task:"CVE scan returned 3 findings",      cost:"$0.44", cells:3 },
    { id:"w-06", name:"docs-gen",        model:"haiku",         status:"running", progress:89, task:"Generating API reference markdown", cost:"$0.12", cells:15 },
    { id:"w-07", name:"e2e-tests",       model:"claude-sonnet", status:"brood",   progress:0,  task:"Queued — waiting on w-01",          cost:"—",     cells:0 },
    { id:"w-08", name:"perf-profiling",  model:"codex",         status:"running", progress:61, task:"Running k6 load test suite",        cost:"$1.02", cells:8 },
  ];

  const statusColor = { running:T.worker, capped:T.queen, stinging:T.sting, brood:T.brood };
  const statusLabel = { running:"RUNNING", capped:"SEALED", stinging:"STING", brood:"BROOD" };

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      {/* Top bar */}
      <div style={{
        display:"flex", alignItems:"center", justifyContent:"space-between",
        padding:"14px 24px", borderBottom:`1px solid ${T.border}`,
        background: T.cell,
      }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3, fontWeight:700 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ yard</span>
        </div>
        <div style={{ display:"flex", gap:20 }}>
          {[
            { label:"WORKERS", val:"8", color:T.worker },
            { label:"CELLS ACTIVE", val:"71", color:T.signal },
            { label:"SPEND TODAY", val:"$10.12", color:T.honey },
            { label:"STINGS", val:"1", color:T.sting },
          ].map(m => (
            <div key={m.label} style={{ textAlign:"center" }}>
              <div style={{ color:m.color, fontSize:16, fontWeight:700 }}>{m.val}</div>
              <div style={{ color:T.textFaint, fontSize:8, letterSpacing:2 }}>{m.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Worker grid */}
      <div style={{ padding:24, display:"grid", gridTemplateColumns:"repeat(2,1fr)", gap:12 }}>
        {workers.map((w,i) => {
          const sc = statusColor[w.status] || T.textDim;
          const isActive = w.status === "running";
          const animOffset = (tick + i) % workers.length;
          return (
            <div key={w.id} style={{
              background: T.cell,
              border: `1px solid ${w.status === "stinging" ? T.sting+"88" : T.border}`,
              borderLeft: `3px solid ${sc}`,
              borderRadius:8, padding:"12px 16px",
              transition:"border-color 0.3s",
            }}>
              <div style={{ display:"flex", justifyContent:"space-between", marginBottom:8 }}>
                <div style={{ display:"flex", alignItems:"center", gap:8 }}>
                  <Dot color={sc} pulse={isActive && animOffset < 3} />
                  <span style={{ color:T.text, fontSize:12, fontWeight:600 }}>{w.name}</span>
                </div>
                <div style={{ display:"flex", gap:6, alignItems:"center" }}>
                  <Badge color={T.textDim} small>{w.model}</Badge>
                  <Badge color={sc} small>{statusLabel[w.status]}</Badge>
                </div>
              </div>
              <div style={{ color:T.textDim, fontSize:10, marginBottom:8, lineHeight:1.5 }}>{w.task}</div>
              {/* Progress bar */}
              <div style={{ background:T.wall, borderRadius:2, height:3, marginBottom:8 }}>
                <div style={{
                  height:3, borderRadius:2, width:`${w.progress}%`,
                  background: `linear-gradient(90deg, ${sc}88, ${sc})`,
                  transition:"width 0.4s",
                }}/>
              </div>
              <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center" }}>
                <div style={{ display:"flex", gap:4 }}>
                  {Array.from({length:Math.min(w.cells, 12)}).map((_,ci) => (
                    <HexCell key={ci} filled={ci < Math.floor(w.cells * w.progress/100)} color={sc} size={10}/>
                  ))}
                </div>
                <span style={{ color:T.honey, fontSize:10 }}>{w.cost}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 02 — THE GLASS (Observation View — multi-terminal)
═══════════════════════════════════════════════════════ */
function ScreenGlass() {
  const terminals = [
    {
      id:"w-01", name:"auth-refactor", color:T.worker,
      lines:[
        { t:"00:14:22", text:"▶ Running test suite...", c:T.textDim },
        { t:"00:14:23", text:"✓ OAuth callback handler — PASS", c:T.worker },
        { t:"00:14:23", text:"✓ Token refresh logic — PASS", c:T.worker },
        { t:"00:14:24", text:"✗ Scope validation — FAIL", c:T.sting },
        { t:"00:14:24", text:"  Expected: ['read','write'] Got: ['read']", c:T.sting },
        { t:"00:14:25", text:"↻ Rewriting scope handler...", c:T.signal },
        { t:"00:14:27", text:"✓ Scope validation — PASS", c:T.worker },
        { t:"00:14:27", text:"All 24 tests passing ✓", c:T.worker },
      ]
    },
    {
      id:"w-04", name:"db-migrations", color:T.brood,
      lines:[
        { t:"00:14:10", text:"▶ Connecting to dev schema...", c:T.textDim },
        { t:"00:14:11", text:"✓ Connection established", c:T.worker },
        { t:"00:14:11", text:"▶ Running migration 004_add_sessions...", c:T.textDim },
        { t:"00:14:14", text:"  ALTER TABLE users ADD COLUMN session_id UUID", c:T.brood },
        { t:"00:14:14", text:"  CREATE INDEX idx_session ON users(session_id)", c:T.brood },
        { t:"00:14:16", text:"✓ Migration complete — 1,247 rows affected", c:T.worker },
        { t:"00:14:16", text:"▶ Verifying constraints...", c:T.textDim },
        { t:"00:14:17", text:"✓ All FK constraints valid", c:T.worker },
      ]
    },
    {
      id:"w-08", name:"perf-profiling", color:T.signal,
      lines:[
        { t:"00:14:00", text:"▶ k6 load test — ramp 0→100 VUs over 60s", c:T.textDim },
        { t:"00:14:05", text:"  http_req_duration p95=234ms", c:T.signal },
        { t:"00:14:10", text:"  http_req_duration p95=412ms ⚠", c:T.signal },
        { t:"00:14:15", text:"  http_req_failed rate=0.02%", c:T.textDim },
        { t:"00:14:20", text:"  Bottleneck detected: /api/session endpoint", c:T.sting },
        { t:"00:14:21", text:"▶ Analyzing query plan...", c:T.textDim },
        { t:"00:14:23", text:"  Missing index on sessions.user_id", c:T.signal },
        { t:"00:14:24", text:"▶ Dispatching cell to db-migrations worker...", c:T.honey },
      ]
    },
    {
      id:"w-06", name:"docs-gen", color:T.queen,
      lines:[
        { t:"00:14:01", text:"▶ Parsing 48 API endpoints...", c:T.textDim },
        { t:"00:14:03", text:"  Generating markdown for /auth/*", c:T.queen },
        { t:"00:14:05", text:"  Generating markdown for /users/*", c:T.queen },
        { t:"00:14:08", text:"  Generating markdown for /sessions/*", c:T.queen },
        { t:"00:14:12", text:"✓ 48/48 endpoints documented", c:T.worker },
        { t:"00:14:13", text:"▶ Generating OpenAPI spec...", c:T.textDim },
        { t:"00:14:18", text:"✓ openapi.yaml written (4,812 lines)", c:T.worker },
        { t:"00:14:18", text:"▶ Sealing cell — notifying keeper", c:T.honey },
      ]
    },
  ];

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ glass</span>
        </div>
        <div style={{ display:"flex", gap:8 }}>
          <Badge color={T.textDim}>LAYOUT: 2×2</Badge>
          <Badge color={T.worker}>4 ACTIVE</Badge>
        </div>
      </div>

      <div style={{ padding:16, display:"grid", gridTemplateColumns:"1fr 1fr", gridTemplateRows:"1fr 1fr", gap:12, height:"calc(100% - 50px)", minHeight:480 }}>
        {terminals.map(term => (
          <div key={term.id} style={{
            background:"#080810", border:`1px solid ${term.color}33`,
            borderTop:`2px solid ${term.color}`,
            borderRadius:8, display:"flex", flexDirection:"column",
            overflow:"hidden",
          }}>
            {/* Terminal titlebar */}
            <div style={{ display:"flex", alignItems:"center", gap:8, padding:"6px 12px", background:T.cell, borderBottom:`1px solid ${T.border}` }}>
              <Dot color={term.color} pulse />
              <span style={{ color:term.color, fontSize:11, fontWeight:700 }}>{term.id}</span>
              <span style={{ color:T.textDim, fontSize:11 }}>—</span>
              <span style={{ color:T.textDim, fontSize:11 }}>{term.name}</span>
              <span style={{ flex:1 }}/>
              <Badge color={T.textDim} small>LIVE</Badge>
            </div>
            {/* Terminal output */}
            <div style={{ flex:1, padding:"10px 12px", overflow:"hidden", display:"flex", flexDirection:"column", justifyContent:"flex-end", gap:2 }}>
              {term.lines.map((l,i) => (
                <div key={i} style={{ display:"flex", gap:8 }}>
                  <span style={{ color:T.textFaint, fontSize:9, flexShrink:0 }}>{l.t}</span>
                  <span style={{ color:l.c, fontSize:10, lineHeight:1.5 }}>{l.text}</span>
                </div>
              ))}
              <div style={{ display:"flex", gap:8, marginTop:2 }}>
                <span style={{ color:T.textFaint, fontSize:9 }}>—</span>
                <span style={{ color:term.color, fontSize:10 }}>█</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 03 — THE COMB (Task Graph / Memory)
═══════════════════════════════════════════════════════ */
function ScreenComb() {
  const cells = [
    { id:"bd-a1b2", label:"Setup auth middleware",    status:"done",    x:80,  y:60,  deps:[] },
    { id:"bd-c3d4", label:"OAuth callback handler",  status:"done",    x:240, y:60,  deps:["bd-a1b2"] },
    { id:"bd-e5f6", label:"Token refresh logic",     status:"done",    x:400, y:60,  deps:["bd-c3d4"] },
    { id:"bd-g7h8", label:"Scope validation",        status:"running", x:560, y:60,  deps:["bd-e5f6"] },
    { id:"bd-i9j0", label:"Session management",      status:"ready",   x:240, y:180, deps:["bd-c3d4"] },
    { id:"bd-k1l2", label:"User profile endpoint",   status:"brood",   x:400, y:180, deps:["bd-i9j0","bd-g7h8"] },
    { id:"bd-m3n4", label:"Write API docs",          status:"brood",   x:560, y:180, deps:["bd-k1l2"] },
    { id:"bd-o5p6", label:"E2E test suite",          status:"brood",   x:400, y:300, deps:["bd-k1l2"] },
    { id:"bd-q7r8", label:"Performance baseline",    status:"running", x:80,  y:180, deps:["bd-a1b2"] },
    { id:"bd-s9t0", label:"Load test /api/session",  status:"running", x:80,  y:300, deps:["bd-q7r8"] },
  ];

  const statusMeta = {
    done:    { color:T.worker,   label:"HONEY" },
    running: { color:T.signal,   label:"OPEN" },
    ready:   { color:T.brood,    label:"READY" },
    brood:   { color:T.textFaint,label:"CAPPED" },
    sealed:  { color:T.queen,    label:"SEALED" },
  };

  const edges = cells.flatMap(c => c.deps.map(d => {
    const from = cells.find(x=>x.id===d);
    const to = c;
    if (!from || !to) return null;
    return { x1:from.x+56, y1:from.y+20, x2:to.x, y2:to.y+20, color:statusMeta[from.status]?.color || T.border };
  })).filter(Boolean);

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ comb · frame: auth-system</span>
        </div>
        <div style={{ display:"flex", gap:8 }}>
          {Object.entries(statusMeta).map(([k,v]) => (
            <div key={k} style={{ display:"flex", alignItems:"center", gap:4 }}>
              <Dot color={v.color} />
              <span style={{ color:T.textDim, fontSize:9, letterSpacing:1 }}>{v.label}</span>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding:24, position:"relative" }}>
        <svg style={{ position:"absolute", top:24, left:24, width:"calc(100% - 48px)", height:380, pointerEvents:"none" }}>
          {edges.map((e,i) => (
            <line key={i} x1={e.x1} y1={e.y1} x2={e.x2} y2={e.y2}
              stroke={e.color + "60"} strokeWidth={1.5} strokeDasharray={e.color===T.textFaint?"4,3":"none"}/>
          ))}
        </svg>

        <div style={{ position:"relative", height:380 }}>
          {cells.map(cell => {
            const meta = statusMeta[cell.status];
            return (
              <div key={cell.id} style={{
                position:"absolute", left:cell.x, top:cell.y,
                width:140, background:T.cell,
                border:`1px solid ${meta.color}44`,
                borderLeft:`3px solid ${meta.color}`,
                borderRadius:6, padding:"8px 10px",
              }}>
                <div style={{ color:meta.color, fontSize:9, letterSpacing:1, marginBottom:3 }}>{cell.id}</div>
                <div style={{ color:T.text, fontSize:10, lineHeight:1.4 }}>{cell.label}</div>
                <div style={{ marginTop:5 }}><Badge color={meta.color} small>{meta.label}</Badge></div>
              </div>
            );
          })}
        </div>

        {/* Honey stats */}
        <div style={{ display:"flex", gap:12, marginTop:8 }}>
          {[
            { label:"CELLS TOTAL", val:"10", color:T.honey },
            { label:"HONEY", val:"3", color:T.worker },
            { label:"OPEN", val:"3", color:T.signal },
            { label:"CAPPED", val:"4", color:T.textDim },
          ].map(s => (
            <div key={s.label} style={{ background:T.cell, border:`1px solid ${T.border}`, borderRadius:6, padding:"8px 16px", textAlign:"center" }}>
              <div style={{ color:s.color, fontSize:18, fontWeight:700 }}>{s.val}</div>
              <div style={{ color:T.textFaint, fontSize:8, letterSpacing:2 }}>{s.label}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 04 — WORKER DETAIL
═══════════════════════════════════════════════════════ */
function ScreenWorker() {
  const steps = [
    { step:"Plan",    status:"done",    detail:"Analyzed 3 files, identified 7 change points" },
    { step:"Read",    status:"done",    detail:"Read auth/oauth.ts, auth/tokens.ts, tests/auth.spec.ts" },
    { step:"Write",   status:"done",    detail:"Modified scope validation logic in oauth.ts line 234" },
    { step:"Test",    status:"running", detail:"Running npm test -- --grep 'OAuth'" },
    { step:"Review",  status:"brood",   detail:"Pending test pass" },
    { step:"Commit",  status:"brood",   detail:"Pending review" },
    { step:"Seal",    status:"brood",   detail:"Pending commit" },
  ];
  const statusMeta = {
    done:    T.worker,
    running: T.signal,
    brood:   T.textFaint,
  };
  const files = [
    { name:"auth/oauth.ts",         lines:"+14 -3",  color:T.signal },
    { name:"auth/tokens.ts",        lines:"+2 -0",   color:T.worker },
    { name:"tests/auth.spec.ts",    lines:"+28 -0",  color:T.brood },
  ];

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ glass / worker / w-01</span>
        </div>
        <Badge color={T.signal}>RUNNING</Badge>
      </div>

      <div style={{ display:"grid", gridTemplateColumns:"280px 1fr", gap:0 }}>
        {/* Left sidebar */}
        <div style={{ borderRight:`1px solid ${T.border}`, padding:20, display:"flex", flexDirection:"column", gap:16 }}>
          <div>
            <div style={{ color:T.honey, fontSize:18, fontWeight:700, marginBottom:2 }}>w-01</div>
            <div style={{ color:T.text, fontSize:13 }}>auth-refactor</div>
            <div style={{ color:T.textDim, fontSize:10, marginTop:4 }}>claude-opus-4 · 72% progress</div>
          </div>
          <div style={{ background:T.wall, borderRadius:4, height:4 }}>
            <div style={{ height:4, borderRadius:4, width:"72%", background:`linear-gradient(90deg, ${T.signal}88, ${T.signal})` }}/>
          </div>

          {/* Steps */}
          <div>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:8 }}>WORKFLOW</div>
            {steps.map((s,i) => (
              <div key={i} style={{ display:"flex", gap:10, marginBottom:8, alignItems:"flex-start" }}>
                <div style={{ display:"flex", flexDirection:"column", alignItems:"center", paddingTop:2 }}>
                  <Dot color={statusMeta[s.status]} pulse={s.status==="running"} />
                  {i < steps.length-1 && <div style={{ width:1, height:16, background:T.border, margin:"3px 0" }}/>}
                </div>
                <div>
                  <div style={{ color:statusMeta[s.status], fontSize:10, fontWeight:600 }}>{s.step}</div>
                  <div style={{ color:T.textFaint, fontSize:9, lineHeight:1.4 }}>{s.detail}</div>
                </div>
              </div>
            ))}
          </div>

          {/* Files touched */}
          <div>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:8 }}>FILES TOUCHED</div>
            {files.map(f => (
              <div key={f.name} style={{ display:"flex", justifyContent:"space-between", padding:"5px 0", borderBottom:`1px solid ${T.border}` }}>
                <span style={{ color:T.textDim, fontSize:9 }}>{f.name}</span>
                <span style={{ color:f.color, fontSize:9 }}>{f.lines}</span>
              </div>
            ))}
          </div>

          {/* Stats */}
          <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:8 }}>
            {[
              { label:"TOKENS IN",  val:"18.4k" },
              { label:"TOKENS OUT", val:"4.2k" },
              { label:"TOOL CALLS", val:"23" },
              { label:"COST",       val:"$2.14" },
            ].map(s => (
              <div key={s.label} style={{ background:T.wall, borderRadius:4, padding:"8px 10px" }}>
                <div style={{ color:T.honey, fontSize:13, fontWeight:700 }}>{s.val}</div>
                <div style={{ color:T.textFaint, fontSize:8, letterSpacing:1 }}>{s.label}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Terminal */}
        <div style={{ background:"#06060a", padding:16, display:"flex", flexDirection:"column" }}>
          <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:12 }}>LIVE OUTPUT · w-01</div>
          {[
            { t:"00:14:24", text:"✗ scope_validation_test — FAIL: expected ['read','write']", c:T.sting },
            { t:"00:14:25", text:"  Analyzing scope handling in oauth.ts:234...", c:T.textDim },
            { t:"00:14:26", text:"  Found: scope array not being merged correctly", c:T.signal },
            { t:"00:14:26", text:"  Applying fix: Array.from(new Set([...existing, ...requested]))", c:T.brood },
            { t:"00:14:27", text:"✓ Rewriting oauth.ts:234-241...", c:T.worker },
            { t:"00:14:28", text:"  Running tests...", c:T.textDim },
            { t:"00:14:29", text:"✓ scope_validation_test — PASS", c:T.worker },
            { t:"00:14:29", text:"✓ 24/24 tests passing", c:T.worker },
            { t:"00:14:30", text:"  Preparing commit message...", c:T.textDim },
            { t:"00:14:30", text:"▶ fix(auth): correct scope array merge in OAuth handler", c:T.honey },
          ].map((l,i) => (
            <div key={i} style={{ display:"flex", gap:12, marginBottom:3 }}>
              <span style={{ color:T.textFaint, fontSize:9, flexShrink:0 }}>{l.t}</span>
              <span style={{ color:l.c, fontSize:10, lineHeight:1.6 }}>{l.text}</span>
            </div>
          ))}
          <div style={{ display:"flex", gap:8, marginTop:6 }}>
            <span style={{ color:T.textFaint, fontSize:9 }}>00:14:31</span>
            <span style={{ color:T.signal, fontSize:10 }}>█</span>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 05 — THE WAGGLE (Skill Registry)
═══════════════════════════════════════════════════════ */
function ScreenWaggle() {
  const skills = [
    { id:"tdd",          name:"test-driven-development", category:"methodology", platforms:["claude","codex","gemini"], uses:1847, rating:4.9, desc:"Enforce RED→GREEN→REFACTOR. Deletes code written before tests.", official:true },
    { id:"git-pr",       name:"github-pr-reviewer",       category:"integration", platforms:["claude","codex"],         uses:923,  rating:4.7, desc:"Fetches PR diff, analyzes for correctness, security, code style.", official:true },
    { id:"perf-test",    name:"neoload-performance",      category:"testing",     platforms:["claude"],                 uses:412,  rating:4.5, desc:"Generates NeoLoad scenarios, runs breakpoint discovery.", official:false },
    { id:"tosca",        name:"tosca-cloud-integration",  category:"testing",     platforms:["claude","codex"],         uses:289,  rating:4.6, desc:"Manages Tosca Cloud test executions and result parsing.", official:false },
    { id:"postman-gen",  name:"postman-collection-gen",   category:"api",         platforms:["claude"],                 uses:614,  rating:4.4, desc:"Generates Postman collections from OpenAPI specs.", official:false },
    { id:"security",     name:"security-scanner",         category:"security",    platforms:["claude","codex","gemini"], uses:1203, rating:4.8, desc:"CVE scanning, OWASP checks, dependency audit.", official:true },
    { id:"docs-gen",     name:"api-docs-generator",       category:"docs",        platforms:["claude","codex"],         uses:876,  rating:4.6, desc:"Generates markdown docs and OpenAPI specs from code.", official:true },
    { id:"db-review",    name:"database-reviewer",        category:"data",        platforms:["claude"],                 uses:334,  rating:4.3, desc:"Reviews schema migrations, checks for missing indexes.", official:false },
  ];
  const catColor = { methodology:T.queen, integration:T.brood, testing:T.signal, security:T.sting, api:T.honey, docs:T.worker, data:T.textDim };

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ waggle</span>
        </div>
        <div style={{ color:T.textDim, fontSize:10 }}>8 blueprints loaded · deferred loading ACTIVE</div>
      </div>

      <div style={{ padding:"16px 24px", borderBottom:`1px solid ${T.border}`, display:"flex", gap:8, flexWrap:"wrap" }}>
        {Object.entries(catColor).map(([cat,c]) => (
          <div key={cat} style={{
            background:T.cell, border:`1px solid ${c}33`, borderRadius:20,
            padding:"4px 12px", cursor:"pointer",
          }}>
            <span style={{ color:c, fontSize:10 }}>{cat}</span>
          </div>
        ))}
      </div>

      <div style={{ padding:16, display:"flex", flexDirection:"column", gap:8 }}>
        {skills.map(skill => {
          const cc = catColor[skill.category] || T.textDim;
          return (
            <div key={skill.id} style={{
              background:T.cell, border:`1px solid ${T.border}`,
              borderLeft:`3px solid ${cc}`, borderRadius:8,
              padding:"12px 16px", display:"flex", alignItems:"center", gap:16,
            }}>
              <div style={{ flex:1 }}>
                <div style={{ display:"flex", alignItems:"center", gap:8, marginBottom:4 }}>
                  <span style={{ color:T.text, fontSize:12, fontWeight:600 }}>{skill.name}</span>
                  {skill.official && <Badge color={T.honey} small>OFFICIAL</Badge>}
                  <Badge color={cc} small>{skill.category}</Badge>
                </div>
                <div style={{ color:T.textDim, fontSize:10, lineHeight:1.5 }}>{skill.desc}</div>
              </div>
              <div style={{ display:"flex", gap:8, flexShrink:0 }}>
                {skill.platforms.map(p => <Badge key={p} color={T.textDim} small>{p}</Badge>)}
              </div>
              <div style={{ textAlign:"right", flexShrink:0 }}>
                <div style={{ color:T.honey, fontSize:12 }}>★ {skill.rating}</div>
                <div style={{ color:T.textFaint, fontSize:9 }}>{skill.uses.toLocaleString()} runs</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 06 — THE KEEPER (Human-in-the-loop approvals)
═══════════════════════════════════════════════════════ */
function ScreenKeeper() {
  const [approved, setApproved] = useState({});
  const approvals = [
    {
      id:"seal-01", worker:"w-03", task:"api-integration", urgency:"high",
      title:"Merge to main: API integration complete",
      summary:"Worker w-03 has completed the full API integration layer. 47 new endpoints, 312 tests passing, OpenAPI spec generated. Requesting merge to main branch.",
      diff:"+847 -23 lines across 12 files",
      risks:["No breaking changes detected","All existing tests pass","New endpoints add session management"],
      cost:"$4.20 spent",
    },
    {
      id:"seal-02", worker:"w-06", task:"docs-gen", urgency:"low",
      title:"Publish API docs to /docs",
      summary:"Documentation generation complete. OpenAPI spec and markdown reference ready. Requesting permission to write to /docs directory.",
      diff:"+4,812 lines in docs/",
      risks:["Write to public docs directory","No code changes"],
      cost:"$0.12 spent",
    },
    {
      id:"seal-03", worker:"w-05", task:"security-audit", urgency:"critical",
      title:"⚠ 3 CVEs found — action required",
      summary:"Security scan found 3 vulnerabilities: 1 critical (prototype pollution in lodash 4.17.19), 2 medium. Worker requests permission to apply patches.",
      diff:"package.json updates + 2 code patches",
      risks:["CVE-2021-23337 (CRITICAL) in lodash","Update lodash to 4.17.21","Patch 2 XSS vectors in input sanitization"],
      cost:"$0.44 spent",
    },
  ];

  const urgencyColor = { critical:T.sting, high:T.signal, low:T.worker };

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ keeper · 3 seals await</span>
        </div>
        <div style={{ display:"flex", gap:8 }}>
          <Badge color={T.sting}>1 CRITICAL</Badge>
          <Badge color={T.signal}>1 HIGH</Badge>
          <Badge color={T.worker}>1 LOW</Badge>
        </div>
      </div>

      <div style={{ padding:20, display:"flex", flexDirection:"column", gap:16 }}>
        {approvals.map(ap => {
          const uc = urgencyColor[ap.urgency];
          const isApproved = approved[ap.id];
          return (
            <div key={ap.id} style={{
              background: T.cell,
              border:`1px solid ${isApproved ? T.worker+"55" : uc+"55"}`,
              borderRadius:10, padding:20,
              opacity: isApproved ? 0.6 : 1,
            }}>
              <div style={{ display:"flex", justifyContent:"space-between", alignItems:"flex-start", marginBottom:12 }}>
                <div>
                  <div style={{ display:"flex", alignItems:"center", gap:8, marginBottom:4 }}>
                    <Badge color={uc}>{ap.urgency.toUpperCase()}</Badge>
                    <Badge color={T.textDim} small>{ap.worker}</Badge>
                    <Badge color={T.textDim} small>{ap.task}</Badge>
                  </div>
                  <div style={{ color:T.text, fontSize:14, fontWeight:600 }}>{ap.title}</div>
                </div>
                <span style={{ color:T.honey, fontSize:11 }}>{ap.cost}</span>
              </div>

              <p style={{ color:T.textDim, fontSize:11, lineHeight:1.7, marginBottom:12 }}>{ap.summary}</p>

              <div style={{ display:"flex", gap:12, marginBottom:12 }}>
                <div style={{ background:T.wall, borderRadius:4, padding:"6px 10px", flex:1 }}>
                  <div style={{ color:T.textFaint, fontSize:8, letterSpacing:2, marginBottom:3 }}>DIFF</div>
                  <div style={{ color:T.signal, fontSize:10 }}>{ap.diff}</div>
                </div>
                <div style={{ background:T.wall, borderRadius:4, padding:"6px 10px", flex:2 }}>
                  <div style={{ color:T.textFaint, fontSize:8, letterSpacing:2, marginBottom:3 }}>RISKS / CHANGES</div>
                  {ap.risks.map((r,i) => <div key={i} style={{ color:i===0 && ap.urgency==="critical" ? T.sting : T.textDim, fontSize:10, lineHeight:1.6 }}>· {r}</div>)}
                </div>
              </div>

              {!isApproved ? (
                <div style={{ display:"flex", gap:8 }}>
                  <button onClick={() => setApproved(p=>({...p,[ap.id]:true}))} style={{
                    background:T.worker+"22", border:`1px solid ${T.worker}`, borderRadius:6,
                    padding:"7px 20px", color:T.worker, fontSize:11, cursor:"pointer", fontFamily:"inherit",
                  }}>APPROVE & UNSEAL</button>
                  <button style={{
                    background:T.sting+"22", border:`1px solid ${T.sting}55`, borderRadius:6,
                    padding:"7px 20px", color:T.sting, fontSize:11, cursor:"pointer", fontFamily:"inherit",
                  }}>REJECT</button>
                  <button style={{
                    background:"transparent", border:`1px solid ${T.border}`, borderRadius:6,
                    padding:"7px 20px", color:T.textDim, fontSize:11, cursor:"pointer", fontFamily:"inherit",
                  }}>VIEW DIFF</button>
                </div>
              ) : (
                <div style={{ color:T.worker, fontSize:11 }}>✓ Approved — unsealing cell and merging</div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 07 — THE SMOKER (CLI Web Bridge)
═══════════════════════════════════════════════════════ */
function ScreenSmoker() {
  const [cmd, setCmd] = useState("");
  const history = [
    { type:"cmd",  text:"hive yard status" },
    { type:"out",  text:"8 workers active · 71 cells · $10.12 spent today" },
    { type:"cmd",  text:"hive worker w-01 tail" },
    { type:"out",  text:"[w-01 auth-refactor] ✓ 24/24 tests passing" },
    { type:"cmd",  text:"hive comb bd-g7h8 status" },
    { type:"out",  text:"Cell bd-g7h8: Scope validation · RUNNING · claimed by w-01" },
    { type:"cmd",  text:"hive swarm spawn --task 'add rate limiting to /api/session' --model claude-opus" },
    { type:"out",  text:"↳ Creating cell bd-u1v2 · Spawning worker w-09 · Dispatching..." },
    { type:"out",  text:"✓ Worker w-09 started · cost budget: $5.00" },
    { type:"cmd",  text:"hive keeper list" },
    { type:"out",  text:"3 seals pending · 1 CRITICAL (w-05) · 1 HIGH (w-03) · 1 LOW (w-06)" },
    { type:"cmd",  text:"hive worker w-05 approve seal-03" },
    { type:"out",  text:"⚠ Seal-03 is CRITICAL urgency. Confirm? [y/N]" },
  ];
  const quickCmds = [
    "hive yard status",
    "hive swarm status",
    "hive keeper list",
    "hive comb frame list",
    "hive worker list --active",
    "hive yield today",
    "hive trail last --n 20",
    "hive waggle list --category testing",
  ];

  return (
    <div style={{ background:"#06060a", minHeight:"100%", fontFamily:"'Courier New',monospace", display:"flex", flexDirection:"column" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ smoker · web CLI bridge</span>
        </div>
        <Badge color={T.worker}>CONNECTED · localhost:4242</Badge>
      </div>

      <div style={{ display:"flex", flex:1 }}>
        {/* Quick commands sidebar */}
        <div style={{ width:220, borderRight:`1px solid ${T.border}`, padding:16 }}>
          <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:10 }}>QUICK COMMANDS</div>
          {quickCmds.map((qc,i) => (
            <div key={i} onClick={() => setCmd(qc)} style={{
              color:T.textDim, fontSize:10, padding:"5px 8px", borderRadius:4,
              marginBottom:3, cursor:"pointer", background:"transparent",
              ":hover":{ background:T.wall },
            }}
            onMouseEnter={e=>e.target.style.color=T.honey}
            onMouseLeave={e=>e.target.style.color=T.textDim}>
              {qc}
            </div>
          ))}
        </div>

        {/* Main terminal */}
        <div style={{ flex:1, display:"flex", flexDirection:"column", padding:20 }}>
          <div style={{ flex:1, marginBottom:16, display:"flex", flexDirection:"column", gap:3, justifyContent:"flex-end" }}>
            {history.map((h,i) => (
              <div key={i} style={{ display:"flex", gap:10 }}>
                <span style={{ color: h.type==="cmd" ? T.honey : T.textDim, flexShrink:0 }}>
                  {h.type==="cmd" ? "❯" : " "}
                </span>
                <span style={{ color: h.type==="cmd" ? T.text : T.worker, fontSize:11, lineHeight:1.7 }}>
                  {h.text}
                </span>
              </div>
            ))}
          </div>

          {/* Input */}
          <div style={{ display:"flex", alignItems:"center", gap:10, background:T.cell, border:`1px solid ${T.border}`, borderRadius:6, padding:"10px 14px" }}>
            <span style={{ color:T.honey, fontSize:12 }}>❯</span>
            <input
              value={cmd}
              onChange={e=>setCmd(e.target.value)}
              placeholder="hive ..."
              style={{
                flex:1, background:"transparent", border:"none", outline:"none",
                color:T.text, fontSize:11, fontFamily:"'Courier New',monospace",
              }}
            />
            <span style={{ color:T.textFaint, fontSize:9 }}>TAB to complete · ↑↓ history</span>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 08 — THE TRAIL (Traces / Observability)
═══════════════════════════════════════════════════════ */
function ScreenTrail() {
  const spans = [
    { id:"span-root", name:"hive.run · bd-g7h8", dur:12400, start:0,    depth:0, color:T.honey, tokens:"22.6k/4.2k" },
    { id:"span-01",   name:"worker.claim · w-01",  dur:120,  start:50,  depth:1, color:T.worker, tokens:"—" },
    { id:"span-02",   name:"skill.load · tdd",     dur:80,   start:200, depth:1, color:T.queen, tokens:"0.9k/0" },
    { id:"span-03",   name:"tool.read · oauth.ts",  dur:340,  start:320, depth:2, color:T.brood, tokens:"4.1k/0" },
    { id:"span-04",   name:"llm.generate · claude", dur:3200, start:700, depth:2, color:T.signal, tokens:"18.4k/4.2k" },
    { id:"span-05",   name:"tool.write · oauth.ts", dur:210,  start:4000,depth:2, color:T.brood, tokens:"0/0.8k" },
    { id:"span-06",   name:"tool.run · npm test",   dur:4800, start:4300,depth:2, color:T.signal, tokens:"—" },
    { id:"span-07",   name:"comb.close · bd-g7h8",  dur:90,   start:9200,depth:1, color:T.worker, tokens:"—" },
  ];
  const total = 12400;
  const scale = 560 / total;

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ trail · trace: bd-g7h8</span>
        </div>
        <div style={{ display:"flex", gap:12 }}>
          <span style={{ color:T.textDim, fontSize:10 }}>Duration: 12.4s</span>
          <span style={{ color:T.honey, fontSize:10 }}>Cost: $2.14</span>
          <span style={{ color:T.worker, fontSize:10 }}>Status: ✓ COMPLETE</span>
        </div>
      </div>

      <div style={{ padding:24 }}>
        {/* Waterfall */}
        <div style={{ marginBottom:24 }}>
          <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:12 }}>SPAN WATERFALL</div>
          {spans.map(span => (
            <div key={span.id} style={{ display:"flex", alignItems:"center", gap:0, marginBottom:4, height:26 }}>
              <div style={{ width:260, display:"flex", alignItems:"center", paddingLeft: span.depth * 16 }}>
                <span style={{ color:span.color, fontSize:10 }}>{span.name}</span>
              </div>
              <div style={{ flex:1, position:"relative", height:20, background:T.wall, borderRadius:2, overflow:"hidden" }}>
                <div style={{
                  position:"absolute",
                  left: span.start * scale,
                  width: Math.max(span.dur * scale, 4),
                  height:"100%",
                  background: span.color + "55",
                  borderLeft:`2px solid ${span.color}`,
                  borderRadius:2,
                }}/>
              </div>
              <div style={{ width:100, textAlign:"right", paddingLeft:12 }}>
                <span style={{ color:T.textDim, fontSize:9 }}>{span.dur >= 1000 ? `${(span.dur/1000).toFixed(1)}s` : `${span.dur}ms`}</span>
              </div>
              <div style={{ width:100, textAlign:"right" }}>
                <span style={{ color:T.textFaint, fontSize:9 }}>{span.tokens}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Event log */}
        <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:12 }}>TRAIL LOG</div>
        <div style={{ display:"flex", flexDirection:"column", gap:4 }}>
          {[
            { time:"+0ms",    event:"RUN_STARTED",      detail:"Cell bd-g7h8 · worker w-01 assigned", color:T.honey },
            { time:"+50ms",   event:"STEP_STARTED",     detail:"skill:tdd loaded · 896 tokens injected", color:T.queen },
            { time:"+700ms",  event:"TOOL_CALL_START",  detail:"read_file · auth/oauth.ts", color:T.brood },
            { time:"+1040ms", event:"LLM_GENERATE",     detail:"claude-opus-4 · streaming · 18.4k tokens in", color:T.signal },
            { time:"+4240ms", event:"TOOL_CALL_START",  detail:"write_file · auth/oauth.ts:234-241", color:T.brood },
            { time:"+4450ms", event:"TOOL_CALL_START",  detail:"run_command · npm test -- --grep OAuth", color:T.signal },
            { time:"+9250ms", event:"STEP_FINISHED",    detail:"All 24 tests passing", color:T.worker },
            { time:"+9340ms", event:"RUN_FINISHED",     detail:"Cell sealed · comb updated", color:T.honey },
          ].map((ev,i) => (
            <div key={i} style={{ display:"flex", gap:12, padding:"5px 0", borderBottom:`1px solid ${T.border}` }}>
              <span style={{ color:T.textFaint, fontSize:9, width:60, flexShrink:0 }}>{ev.time}</span>
              <span style={{ color:ev.color, fontSize:9, width:140, flexShrink:0, letterSpacing:0.5 }}>{ev.event}</span>
              <span style={{ color:T.textDim, fontSize:9 }}>{ev.detail}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 09 — THE YIELD (Metrics)
═══════════════════════════════════════════════════════ */
function ScreenYield() {
  const days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];
  const costs = [4.2, 8.7, 12.1, 6.4, 15.8, 9.3, 10.1];
  const tasks = [12, 28, 35, 18, 41, 24, 29];
  const maxCost = Math.max(...costs);
  const maxTasks = Math.max(...tasks);

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ yield · this week</span>
        </div>
        <Badge color={T.worker}>↑ 23% vs last week</Badge>
      </div>

      <div style={{ padding:24 }}>
        {/* KPIs */}
        <div style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:12, marginBottom:24 }}>
          {[
            { label:"TOTAL SPENT",    val:"$66.60", change:"+$12.40", color:T.honey },
            { label:"CELLS CLOSED",   val:"187",    change:"+41",     color:T.worker },
            { label:"AVG COST/CELL",  val:"$0.36",  change:"-$0.04",  color:T.signal },
            { label:"STINGS (ERRORS)", val:"7",     change:"-3",      color:T.sting },
          ].map(k => (
            <div key={k.label} style={{ background:T.cell, border:`1px solid ${k.color}33`, borderTop:`3px solid ${k.color}`, borderRadius:8, padding:"14px 18px" }}>
              <div style={{ color:k.color, fontSize:24, fontWeight:700, marginBottom:2 }}>{k.val}</div>
              <div style={{ color:T.textFaint, fontSize:8, letterSpacing:2, marginBottom:6 }}>{k.label}</div>
              <div style={{ color:k.color, fontSize:10 }}>{k.change} vs last week</div>
            </div>
          ))}
        </div>

        <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:16 }}>
          {/* Cost chart */}
          <div style={{ background:T.cell, border:`1px solid ${T.border}`, borderRadius:8, padding:16 }}>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:16 }}>DAILY YIELD (COST $)</div>
            <div style={{ display:"flex", alignItems:"flex-end", gap:8, height:100 }}>
              {days.map((d,i) => (
                <div key={d} style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:4 }}>
                  <div style={{ color:T.honey, fontSize:9 }}>${costs[i]}</div>
                  <div style={{
                    width:"100%", borderRadius:"2px 2px 0 0",
                    height: (costs[i] / maxCost) * 70,
                    background:`linear-gradient(180deg, ${T.honey}, ${T.honeyDim})`,
                  }}/>
                  <div style={{ color:T.textFaint, fontSize:8 }}>{d}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Tasks chart */}
          <div style={{ background:T.cell, border:`1px solid ${T.border}`, borderRadius:8, padding:16 }}>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:16 }}>DAILY CELLS CLOSED</div>
            <div style={{ display:"flex", alignItems:"flex-end", gap:8, height:100 }}>
              {days.map((d,i) => (
                <div key={d} style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:4 }}>
                  <div style={{ color:T.worker, fontSize:9 }}>{tasks[i]}</div>
                  <div style={{
                    width:"100%", borderRadius:"2px 2px 0 0",
                    height: (tasks[i] / maxTasks) * 70,
                    background:`linear-gradient(180deg, ${T.worker}, ${T.worker}88)`,
                  }}/>
                  <div style={{ color:T.textFaint, fontSize:8 }}>{d}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Model breakdown */}
          <div style={{ background:T.cell, border:`1px solid ${T.border}`, borderRadius:8, padding:16 }}>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:12 }}>MODEL BREAKDOWN</div>
            {[
              { model:"claude-opus-4",   pct:62, cost:"$41.30", color:T.queen },
              { model:"claude-sonnet-4", pct:24, cost:"$15.98", color:T.brood },
              { model:"claude-haiku",    pct:8,  cost:"$5.33",  color:T.worker },
              { model:"codex",           pct:6,  cost:"$3.99",  color:T.signal },
            ].map(m => (
              <div key={m.model} style={{ marginBottom:10 }}>
                <div style={{ display:"flex", justifyContent:"space-between", marginBottom:3 }}>
                  <span style={{ color:T.textDim, fontSize:10 }}>{m.model}</span>
                  <span style={{ color:m.color, fontSize:10 }}>{m.cost} · {m.pct}%</span>
                </div>
                <div style={{ background:T.wall, borderRadius:2, height:3 }}>
                  <div style={{ height:3, borderRadius:2, width:`${m.pct}%`, background:m.color }}/>
                </div>
              </div>
            ))}
          </div>

          {/* Top workers by yield */}
          <div style={{ background:T.cell, border:`1px solid ${T.border}`, borderRadius:8, padding:16 }}>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:12 }}>TOP WORKERS THIS WEEK</div>
            {[
              { name:"auth-refactor",   cells:28, cost:"$18.40" },
              { name:"api-integration", cells:22, cost:"$14.20" },
              { name:"e2e-tests",       cells:19, cost:"$4.80" },
              { name:"security-audit",  cells:17, cost:"$7.60" },
              { name:"docs-gen",        cells:31, cost:"$3.10" },
            ].map((w,i) => (
              <div key={w.name} style={{ display:"flex", alignItems:"center", gap:10, marginBottom:8, padding:"5px 0", borderBottom:`1px solid ${T.border}` }}>
                <span style={{ color:T.textFaint, fontSize:9, width:14 }}>#{i+1}</span>
                <span style={{ color:T.text, fontSize:10, flex:1 }}>{w.name}</span>
                <Badge color={T.worker} small>{w.cells} cells</Badge>
                <span style={{ color:T.honey, fontSize:10 }}>{w.cost}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREEN 10 — THE QUEEN (Orchestrator Control Plane)
═══════════════════════════════════════════════════════ */
function ScreenQueen() {
  const [msg, setMsg] = useState("");
  const conversation = [
    { role:"keeper", text:"Add rate limiting to all /api/session endpoints. Max 100 req/min per IP. Use Redis." },
    { role:"queen",  text:"Understood. Analyzing the session endpoints and current architecture..." },
    { role:"queen",  text:"I'll decompose this into 4 cells:\n• bd-u1: Audit all /api/session routes (w-09, haiku)\n• bd-u2: Implement Redis rate limiter middleware (w-09, opus)\n• bd-u3: Add rate limit headers to responses (w-09, sonnet)\n• bd-u4: Write integration tests (w-09, sonnet)\nDispatch when ready?" },
    { role:"keeper", text:"Yes, dispatch. Budget $8." },
    { role:"queen",  text:"Swarming. 4 cells created in frame 'rate-limiting'. Worker w-09 spawned (claude-opus-4). Budget cap: $8.00. Estimated completion: ~18 minutes.\n\nRunning bd-u1 first to audit scope before implementation." },
  ];

  const routing = [
    { task:"simple file read",          model:"haiku",  reason:"< 4k tokens, no reasoning needed" },
    { task:"complex refactor",          model:"opus-4", reason:"multi-file, high reasoning" },
    { task:"test generation",           model:"sonnet", reason:"structured output, medium complexity" },
    { task:"documentation",             model:"haiku",  reason:"template-driven, cost sensitive" },
    { task:"security analysis",         model:"opus-4", reason:"critical path, needs deep reasoning" },
  ];

  return (
    <div style={{ background:T.hive, minHeight:"100%", fontFamily:"'Courier New',monospace", display:"flex", flexDirection:"column" }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"14px 24px", borderBottom:`1px solid ${T.border}`, background:T.cell }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:18, color:T.honey }}>⬡</span>
          <span style={{ color:T.honey, fontSize:13, letterSpacing:3 }}>THE HIVE</span>
          <span style={{ color:T.textFaint, fontSize:10 }}>/ queen · orchestrator</span>
        </div>
        <div style={{ display:"flex", gap:12 }}>
          <Badge color={T.queen}>QUEEN ONLINE</Badge>
          <Badge color={T.signal}>BUDGET: $5.83 / $20.00</Badge>
        </div>
      </div>

      <div style={{ display:"grid", gridTemplateColumns:"1fr 280px", flex:1 }}>
        {/* Chat with Queen */}
        <div style={{ display:"flex", flexDirection:"column", borderRight:`1px solid ${T.border}` }}>
          <div style={{ flex:1, padding:20, display:"flex", flexDirection:"column", gap:12, justifyContent:"flex-end", overflow:"hidden" }}>
            {conversation.map((c,i) => (
              <div key={i} style={{
                alignSelf: c.role==="keeper" ? "flex-end" : "flex-start",
                maxWidth:"75%",
              }}>
                <div style={{ color:c.role==="keeper" ? T.honey : T.queen, fontSize:9, letterSpacing:2, marginBottom:4 }}>
                  {c.role==="keeper" ? "KEEPER" : "⬡ QUEEN"}
                </div>
                <div style={{
                  background: c.role==="keeper" ? T.honey+"22" : T.queen+"15",
                  border:`1px solid ${c.role==="keeper" ? T.honey+"44" : T.queen+"33"}`,
                  borderRadius: c.role==="keeper" ? "10px 10px 2px 10px" : "10px 10px 10px 2px",
                  padding:"10px 14px",
                  color:T.text, fontSize:11, lineHeight:1.7,
                  whiteSpace:"pre-line",
                }}>{c.text}</div>
              </div>
            ))}
          </div>
          <div style={{ padding:"12px 20px", borderTop:`1px solid ${T.border}`, display:"flex", gap:10 }}>
            <input
              value={msg}
              onChange={e=>setMsg(e.target.value)}
              placeholder="Tell the Queen what to build..."
              style={{
                flex:1, background:T.cell, border:`1px solid ${T.border}`,
                borderRadius:6, padding:"9px 14px",
                color:T.text, fontSize:11, fontFamily:"'Courier New',monospace", outline:"none",
              }}
            />
            <button style={{
              background:T.queen+"22", border:`1px solid ${T.queen}`,
              borderRadius:6, padding:"9px 18px", color:T.queen,
              fontSize:11, cursor:"pointer", fontFamily:"inherit",
            }}>DISPATCH</button>
          </div>
        </div>

        {/* Right panel — routing + status */}
        <div style={{ padding:16, display:"flex", flexDirection:"column", gap:16 }}>
          <div>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:10 }}>ROUTING LOGIC</div>
            {routing.map((r,i) => (
              <div key={i} style={{ marginBottom:8, padding:"8px 10px", background:T.cell, borderRadius:6, border:`1px solid ${T.border}` }}>
                <div style={{ color:T.textDim, fontSize:9, marginBottom:2 }}>{r.task}</div>
                <div style={{ display:"flex", justifyContent:"space-between" }}>
                  <Badge color={T.queen} small>{r.model}</Badge>
                  <span style={{ color:T.textFaint, fontSize:8 }}>{r.reason}</span>
                </div>
              </div>
            ))}
          </div>

          <div>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:10 }}>ACTIVE SWARM</div>
            {[
              { id:"w-01", task:"auth-refactor",   pct:72, color:T.worker },
              { id:"w-03", task:"api-integration", pct:100,color:T.queen },
              { id:"w-09", task:"rate-limiting",   pct:8,  color:T.signal },
            ].map(w => (
              <div key={w.id} style={{ marginBottom:8 }}>
                <div style={{ display:"flex", justifyContent:"space-between", marginBottom:3 }}>
                  <span style={{ color:w.color, fontSize:10 }}>{w.id} · {w.task}</span>
                  <span style={{ color:T.textDim, fontSize:9 }}>{w.pct}%</span>
                </div>
                <div style={{ background:T.wall, borderRadius:2, height:3 }}>
                  <div style={{ height:3, borderRadius:2, width:`${w.pct}%`, background:w.color }}/>
                </div>
              </div>
            ))}
          </div>

          <div style={{ background:T.cell, border:`1px solid ${T.honey}22`, borderRadius:6, padding:12 }}>
            <div style={{ color:T.textFaint, fontSize:9, letterSpacing:2, marginBottom:6 }}>BUDGET</div>
            <div style={{ display:"flex", justifyContent:"space-between", marginBottom:6 }}>
              <span style={{ color:T.honey, fontSize:18, fontWeight:700 }}>$5.83</span>
              <span style={{ color:T.textDim, fontSize:11 }}>/ $20.00</span>
            </div>
            <div style={{ background:T.wall, borderRadius:2, height:6 }}>
              <div style={{ height:6, borderRadius:2, width:"29%", background:`linear-gradient(90deg, ${T.honey}88, ${T.honey})` }}/>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   ROOT — SCREEN SELECTOR
═══════════════════════════════════════════════════════ */
const SCREEN_MAP = {
  yard:    ScreenYard,
  glass:   ScreenGlass,
  comb:    ScreenComb,
  worker:  ScreenWorker,
  waggle:  ScreenWaggle,
  keeper:  ScreenKeeper,
  smoker:  ScreenSmoker,
  trail:   ScreenTrail,
  yield:   ScreenYield,
  queen:   ScreenQueen,
};

export default function App() {
  const [active, setActive] = useState("yard");
  const ActiveScreen = SCREEN_MAP[active];

  return (
    <div style={{ background:T.void, minHeight:"100vh", display:"flex", flexDirection:"column" }}>
      <style>{`
        * { box-sizing:border-box; margin:0; padding:0; }
        @keyframes pulseRing { 0%,100%{box-shadow:0 0 0 0 currentColor} 50%{box-shadow:0 0 0 4px transparent} }
        ::-webkit-scrollbar { width:4px; } ::-webkit-scrollbar-track { background:transparent; }
        ::-webkit-scrollbar-thumb { background:#2a2a38; border-radius:2px; }
      `}</style>

      {/* Nav rail */}
      <div style={{
        background: "#08080e",
        borderBottom:`1px solid ${T.border}`,
        padding:"0 16px",
        display:"flex", gap:2, overflowX:"auto",
        flexShrink:0,
      }}>
        {screens.map(s => (
          <button key={s.id} onClick={() => setActive(s.id)} style={{
            background: active===s.id ? T.honey+"18" : "transparent",
            border:"none",
            borderBottom:`2px solid ${active===s.id ? T.honey : "transparent"}`,
            padding:"10px 14px",
            color: active===s.id ? T.honey : T.textDim,
            fontSize:11, cursor:"pointer", fontFamily:"'Courier New',monospace",
            whiteSpace:"nowrap", transition:"all 0.15s",
            display:"flex", flexDirection:"column", gap:2,
          }}>
            <span style={{ fontWeight: active===s.id ? 700 : 400 }}>{s.label}</span>
            <span style={{ fontSize:9, opacity:0.6 }}>{s.sub}</span>
          </button>
        ))}
      </div>

      {/* Screen */}
      <div style={{ flex:1, overflow:"auto" }}>
        <ActiveScreen />
      </div>
    </div>
  );
}
