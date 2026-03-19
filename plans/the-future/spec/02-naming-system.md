# 02 - Naming System Specification

A naming system for a clean-sheet AI agent orchestration platform, synthesized
from five existing platforms (Gas Town, Overstory, gstack, ATSA, Beads).

This document defines evaluation criteria, maps ~25 functional concepts,
develops five fully-realized theme candidates, scores them, and provides
a methodology for the final decision.

---

## 1. Why Naming Matters

Names are not decoration. They are the primary interface between a user and
a system. Every interaction — typing a CLI command, reading a log, explaining
the platform to a colleague — passes through the naming layer. The cost of
bad names compounds across every user, every day, forever.

### The Compounding Cost of Bad Names

A name that fails to telegraph its function creates a micro-lookup on every
encounter. Over a 25-concept system used daily, this adds up:

- **Week 1:** New user encounters `gt sling bd-a1b2 rig-prod` and must look up
  what sling, bd, and rig mean. Three lookups for one command.
- **Week 4:** User still hesitates before typing `Protomolecule` vs `Molecule`
  vs `Formula`. The distinction is clear in the docs, unclear in the name.
- **Month 6:** User explaining the system to a teammate says "so the Deacon
  watches the Boot which watches the Deacon..." — the circular naming undermines
  the conceptual clarity.

Contrast this with gstack: `/review`, `/ship`, `/qa`. Zero lookups. The name
*is* the documentation. But gstack pays a different price — its names have no
personality, no cohesion, and no extensibility. When you need a 14th role, you
get `/do-another-thing`.

### What Good Names Do

Good names accomplish four things simultaneously:

1. **Telegraph function.** A user who has never seen the system can guess
   roughly what a term means from the name alone.
2. **Create system identity.** A cohesive naming theme makes the platform
   feel like a designed product, not a bag of scripts.
3. **Aid memory.** Distinctive, evocative names stick. Generic names blur
   together. Nobody forgets "Guzzoline" — but nobody can remember which of
   Coordinator/Orchestrator/Lead dispatches work in Overstory.
4. **Scale gracefully.** The theme must have enough vocabulary depth that
   the 30th term feels as natural as the 5th.

### The Budget

This platform needs approximately 25 named concepts spanning roles, work units,
operations, and subsystems. The naming theme must supply all 25 without forcing
terms that feel contrived, stretched, or ambiguous.

---

## 2. Evaluation Criteria

Seven criteria, weighted by their impact on daily platform usage.

| # | Criterion | Weight | Definition |
|---|-----------|--------|------------|
| 1 | **Vocabulary depth** | 5 | Can the theme supply 25+ distinct terms without forcing? A theme that runs dry at 15 terms will produce awkward names for the remainder. |
| 2 | **Function-telegraphing** | 5 | Does each name hint at what it does? A new user reading `forge cast deploy-api` should intuit that something is being created and sent out. |
| 3 | **Memorability** | 4 | Are terms sticky, distinctive, and resistant to confusion with each other or with external tools? "Crucible" is memorable; "Processor" is not. |
| 4 | **Learnability** | 4 | How fast can a new user build a mental model of the entire system? Measured by: can you explain the whole naming scheme in one sentence? |
| 5 | **Extensibility** | 3 | Can new concepts be named without breaking the theme? If the platform adds browser automation in v2, does the theme have a natural term for it? |
| 6 | **Search-friendliness** | 3 | Are terms unique enough that searching docs, Stack Overflow, or Google returns relevant results? "Worker" fails; "Polecat" succeeds (too well). |
| 7 | **Tone** | 3 | Professional enough for enterprise adoption, characterful enough that builders want to use it. Neither sterile nor silly. |

**Maximum possible score: 135** (5 criteria levels x 27 weight points, but
scored per-criterion 1-5 then multiplied by weight).

### Scoring Scale

- **5** — Theme excels at this criterion; best-in-class
- **4** — Strong, minor gaps
- **3** — Adequate, noticeable weaknesses
- **2** — Weak, requires workarounds or forced terms
- **1** — Fails at this criterion; fundamental mismatch

---

## 3. Concepts to Name (~25)

These are the functional concepts that need names, organized by category.
Each row includes the functional description and example names from the
five existing platforms for reference.

### 3.1 The Platform (2 concepts)

| # | Functional Concept | Description | Gas Town | Overstory | gstack | ATSA | Beads |
|---|-------------------|-------------|----------|-----------|--------|------|-------|
| 1 | The platform itself | The product name, used in docs, conversations, marketing | Gas Town | Overstory | gstack | ATSA | Beads |
| 2 | The CLI command | The 2-3 character command typed thousands of times | `gt` | `ov` | `browse` | (slash) | `bd` |

### 3.2 Work Units (4 concepts)

| # | Functional Concept | Description | Gas Town | Overstory | gstack | ATSA |
|---|-------------------|-------------|----------|-----------|--------|------|
| 3 | Atomic task | The smallest unit of trackable work | Bead | Task/Seed | (none) | WorkItem |
| 4 | Workflow template | A reusable recipe for multi-step work | Formula/Protomolecule | (none) | Skill template | SKILL.md |
| 5 | Active workflow | A running instance of a template | Molecule | (none) | (none) | (none) |
| 6 | Ephemeral workflow | A one-off workflow not persisted to history | Wisp | (none) | (none) | (none) |

### 3.3 Agent Roles (8 concepts)

| # | Functional Concept | Description | Gas Town | Overstory | gstack | ATSA |
|---|-------------------|-------------|----------|-----------|--------|------|
| 7 | Coordinator | Top-level orchestrator, decomposes work | Mayor | Coordinator | CEO | Orchestrator |
| 8 | Team lead | Mid-level manager, owns a workstream | (implicit) | Lead | Eng Manager | (none) |
| 9 | Worker | Implementation agent, writes code | Polecat | Builder | (implicit) | {domain}-agent |
| 10 | Reviewer | Validates work quality | (in workflow) | Reviewer | Staff Eng | code-reviewer |
| 11 | Merger | Manages branch integration | Refinery | Merger | Release Eng | (manual) |
| 12 | Scout | Read-only codebase exploration | (none) | Scout | (none) | (none) |
| 13 | Watchdog | Monitors fleet health, detects stalls | Witness/Deacon | Monitor | (none) | (none) |
| 14 | Infrastructure helper | Cleanup, backup, maintenance tasks | Dogs | (none) | (none) | (none) |

### 3.4 Operations (6 concepts)

| # | Functional Concept | Description | Gas Town | Overstory | gstack | ATSA |
|---|-------------------|-------------|----------|-----------|--------|------|
| 15 | Dispatch work | Send a task to a worker | sling | sling | (implicit) | Agent tool |
| 16 | Load context | Prime an agent with relevant knowledge | (implicit) | prime | (implicit) | (implicit) |
| 17 | Check status | Query the state of work/agents | `gt status` | `ov status` | (none) | (none) |
| 18 | Escalate | Elevate a stuck or failed task | DYFJ signal | nudge | (none) | (none) |
| 19 | Hand off | Transfer work between agents or sessions | (convoy) | checkpoint | (none) | context-manager |
| 20 | Merge | Integrate completed work into main | `gt mq` | `ov merge` | `/ship` | (manual) |

### 3.5 Subsystems (7 concepts)

| # | Functional Concept | Description | Gas Town | Overstory | gstack | ATSA |
|---|-------------------|-------------|----------|-----------|--------|------|
| 21 | Work tracker | Durable state for tasks and dependencies | Beads/Dolt | Seeds | (none) | (none) |
| 22 | Expertise store | Organizational memory across sessions | (none) | Mulch | (none) | (none) |
| 23 | Prompt manager | Versioned, composable agent instructions | Formulas | Canopy | Templates | SKILL.md |
| 24 | Communication bus | Inter-agent messaging | (implicit) | Mail | (none) | (none) |
| 25 | Merge queue | Automated branch integration pipeline | Refinery | merge queue | `/ship` | (none) |
| 26 | Quality engine | Test, review, and gate pipeline | (in workflow) | (in workflow) | `/qa` | qe-agent |
| 27 | Browser automation | Playwright-driven UI interaction | (none) | (none) | `browse` | (none) |

### 3.6 Coordination Units (2 concepts)

| # | Functional Concept | Description | Gas Town | Overstory | gstack | ATSA |
|---|-------------------|-------------|----------|-----------|--------|------|
| 28 | Multi-agent effort | A coordinated push involving several agents | Convoy | (implicit) | (none) | (none) |
| 29 | Project workspace | A managed project directory/repo | Rig | (project) | (none) | (none) |

**Total: 29 concepts** (some optional, ~25 required for v1).

---

## 4. Five Theme Candidates

Each candidate provides a complete vocabulary mapping, strengths/weaknesses
analysis, example CLI usage, and example conversational phrasing.

---

### 4.1 Forge — Metalworking and Smithing

**Metaphor family:** The forge is where raw materials become finished goods.
Metal is heated, shaped, tested, and tempered. The metaphor maps naturally to
software: raw requirements are shaped into working code through iterative
refinement, quality testing, and hardening.

**Platform name:** Forge
**CLI command:** `fg`

#### Vocabulary Mapping

| # | Concept | Forge Name | Reasoning |
|---|---------|-----------|-----------|
| 1 | Platform | **Forge** | Where things are created through heat and skill |
| 2 | CLI | **`fg`** | Short, unambiguous, easy to type |
| 3 | Atomic task | **Ingot** | A discrete unit of refined material |
| 4 | Workflow template | **Mold** | A reusable shape that produces consistent output |
| 5 | Active workflow | **Pour** | Molten metal actively filling a mold |
| 6 | Ephemeral workflow | **Spark** | Brief, bright, not preserved |
| 7 | Coordinator | **Crucible** | The vessel where planning and mixing happen |
| 8 | Team lead | **Anvil** | The stable surface where work takes shape |
| 9 | Worker | **Smith** | The one who shapes the metal (Backend Smith, UI Smith) |
| 10 | Reviewer | **Assayer** | Tests quality, purity, and fitness |
| 11 | Merger | **Alloy** | Combines separate metals into a stronger whole |
| 12 | Scout | **Prospector** | Searches for ore (reads codebase, finds patterns) |
| 13 | Watchdog | **Sentinel** | Guards the forge, watches for danger |
| 14 | Infra helper | **Bellows** | Keeps the fire going, handles airflow (maintenance) |
| 15 | Dispatch work | **cast** | Send an ingot to a smith |
| 16 | Load context | **heat** | Bring material to working temperature |
| 17 | Check status | **gauge** | Measure the temperature/progress |
| 18 | Escalate | **quench** | Rapid cooling — emergency intervention |
| 19 | Hand off | **pass** | Hand the piece to the next station |
| 20 | Merge | **temper** | Final hardening, integration into the whole |
| 21 | Work tracker | **Ledger** | Record of all commissions and ingots |
| 22 | Expertise store | **Lore** | Accumulated knowledge of the craft |
| 23 | Prompt manager | **Patterns** | Templates and designs for smithing |
| 24 | Communication bus | **Herald** | Carries messages between stations |
| 25 | Merge queue | **Annealer** | Controlled cooling and integration pipeline |
| 26 | Quality engine | **Assay** | The testing and certification system |
| 27 | Browser automation | **Lens** | Visual inspection tool |
| 28 | Multi-agent effort | **Commission** | A coordinated order from multiple smiths |
| 29 | Project workspace | **Foundry** | A dedicated workshop for one project |

#### Example CLI Usage

```bash
fg cast ingot-4a2f anvil-backend     # dispatch task to backend team lead
fg gauge commission-12               # check status of multi-agent effort
fg heat smith-ui --context=design    # load design context into UI worker
fg temper foundry-api                # merge completed work in api project
```

#### Example Conversation

> "Cast this ingot to the backend smith. The assayer flagged a purity issue
> on the last pour, so make sure the smith runs the assay before passing
> it to the annealer."

#### Strengths

- **Rich vocabulary:** Metalworking has dozens of precise, well-known terms.
  Extending to 40+ concepts is easy (tongs, flux, slag, weld, rivet, stamp).
- **Creation-focused:** The metaphor is about *making things*, which aligns
  with what the platform does.
- **Professional tone:** Forge/foundry language feels serious and skilled
  without being sterile.
- **Search-friendly:** "Forge assayer" and "forge ingot" return minimal
  false positives.

#### Weaknesses

- **"Forge" collisions:** GitHub has a product called Forge. Atlassian had
  Forge. The word is somewhat overloaded in developer tooling.
- **Some forced terms:** "Quench" for escalation is metaphorically backwards
  (quenching calms things down, escalation heats up). "Bellows" for infra
  helper is a stretch.
- **Industrial tone:** May feel heavy for a modern, lightweight tool.
  Some users might associate forge with slow, manual work.

---

### 4.2 Harbor — Maritime and Shipping

**Metaphor family:** A harbor is a coordination hub where vessels arrive,
cargo is loaded and unloaded, pilots guide ships through channels, and a
lighthouse watches over everything. Maritime logistics maps well to agent
orchestration: routing, loading, dispatching, monitoring.

**Platform name:** Harbor
**CLI command:** `hb`

#### Vocabulary Mapping

| # | Concept | Harbor Name | Reasoning |
|---|---------|------------|-----------|
| 1 | Platform | **Harbor** | The coordination hub where work flows through |
| 2 | CLI | **`hb`** | Short, no conflicts with common commands |
| 3 | Atomic task | **Cargo** | A discrete unit being transported/processed |
| 4 | Workflow template | **Manifest** | A document describing what cargo to move and how |
| 5 | Active workflow | **Voyage** | A manifest in transit |
| 6 | Ephemeral workflow | **Ferry** | Short crossing, not logged in the permanent record |
| 7 | Coordinator | **Harbormaster** | Oversees all traffic, assigns berths, sequences arrivals |
| 8 | Team lead | **Pilot** | Guides a vessel through a specific channel |
| 9 | Worker | **Crew** | The ones doing the work (Deck Crew, Engine Crew) |
| 10 | Reviewer | **Inspector** | Examines cargo quality before clearance |
| 11 | Merger | **Dock** | Where vessels come together, cargo is consolidated |
| 12 | Scout | **Lookout** | Scans the horizon, reports what they see |
| 13 | Watchdog | **Lighthouse** | Always on, warns of danger, guides traffic |
| 14 | Infra helper | **Tugboat** | Helps larger vessels maneuver, handles logistics |
| 15 | Dispatch work | **berth** | Assign cargo to a crew |
| 16 | Load context | **ballast** | Weight that stabilizes the vessel (context grounds the agent) |
| 17 | Check status | **signal** | Flag signals between vessels |
| 18 | Escalate | **mayday** | Emergency call, immediately prioritized |
| 19 | Hand off | **tow** | Transfer cargo between vessels |
| 20 | Merge | **moor** | Secure the vessel, finalize delivery |
| 21 | Work tracker | **Logbook** | Permanent record of all voyages and cargo |
| 22 | Expertise store | **Charts** | Accumulated navigational knowledge |
| 23 | Prompt manager | **Signals** | Standardized communication patterns (flag code) |
| 24 | Communication bus | **Channel** | Dedicated frequency for inter-vessel comms |
| 25 | Merge queue | **Lock** | Canal lock — controlled sequencing through a bottleneck |
| 26 | Quality engine | **Customs** | Inspects and certifies before entry |
| 27 | Browser automation | **Periscope** | Visual observation tool |
| 28 | Multi-agent effort | **Fleet** | Multiple vessels coordinating on a mission |
| 29 | Project workspace | **Berth** | A dedicated slip for one project's vessels |

#### Example CLI Usage

```bash
hb berth cargo-8f3c pilot-backend    # dispatch task to backend team lead
hb signal fleet-12                   # check status of multi-agent effort
hb ballast crew-ui --charts=design   # load design expertise into UI crew
hb moor berth-api                    # merge completed work in api project
```

#### Example Conversation

> "Berth this cargo with the backend crew. Customs flagged a defect on
> the last voyage, so the inspector needs to clear it before it enters
> the lock."

#### Strengths

- **Deep vocabulary:** Maritime has hundreds of terms. Extending to new
  concepts is effortless (starboard, port, bow, stern, keel, rigging,
  compass, sextant, buoy, anchor, gangway, bilge).
- **Natural coordination metaphor:** Harbors literally exist to coordinate
  the arrival, processing, and departure of things — exactly what the
  platform does.
- **Professional and universal:** Maritime terms are well-known globally,
  no cultural barrier.
- **Strong verbs:** berth, moor, signal, tow — all feel like actions.

#### Weaknesses

- **"Harbor" is generic:** Less distinctive than Forge or Hive. Could be
  confused with container (Docker) terminology.
- **Some mixed signals:** "Ballast" for loading context is clever but not
  immediately obvious. "Lock" for merge queue requires canal knowledge.
- **Slightly bureaucratic:** Harbormaster, Inspector, Customs — the tone
  leans institutional rather than creative.
- **Container collision:** Docker already owns "container," and Harbor
  might cause confusion in that ecosystem. (Note: there is also an existing
  open-source project called "Harbor" for container registries.)

---

### 4.3 Grove — Forest Ecology

**Metaphor family:** A grove is a cultivated stand of trees — not wild
forest, but tended woodland. The metaphor extends Overstory's ecological
theme with more precision: trees grow through rings, communicate through
mycorrhizal networks, reproduce through seeds and grafts, and are maintained
through pruning. This version pushes beyond Overstory's generic role names
into richer ecological vocabulary.

**Platform name:** Grove
**CLI command:** `gv`

#### Vocabulary Mapping

| # | Concept | Grove Name | Reasoning |
|---|---------|-----------|-----------|
| 1 | Platform | **Grove** | A tended, living system that grows over time |
| 2 | CLI | **`gv`** | Short, no conflicts |
| 3 | Atomic task | **Seed** | The smallest unit that can grow into something |
| 4 | Workflow template | **Rootstock** | The base onto which new growth is grafted |
| 5 | Active workflow | **Graft** | A rootstock with active growth attached |
| 6 | Ephemeral workflow | **Spore** | Disperses, germinates briefly, leaves no trunk |
| 7 | Coordinator | **Canopy** | The top layer that receives sunlight and distributes resources |
| 8 | Team lead | **Bough** | A major branch that supports smaller branches |
| 9 | Worker | **Sapling** | A young tree actively growing (Backend Sapling, UI Sapling) |
| 10 | Reviewer | **Pruner** | Cuts what does not belong, shapes healthy growth |
| 11 | Merger | **Taproot** | Draws separate nutrients together into the trunk |
| 12 | Scout | **Tendril** | Reaches out, explores, finds surfaces to grip |
| 13 | Watchdog | **Mycelium** | Underground fungal network sensing the health of every tree |
| 14 | Infra helper | **Mulch** | Decomposes old material into nutrients for new growth |
| 15 | Dispatch work | **sow** | Plant a seed in the right soil |
| 16 | Load context | **compost** | Enrich the soil before planting |
| 17 | Check status | **ring** | Read the growth rings (progress indicator) |
| 18 | Escalate | **blight** | Signal disease — something needs immediate attention |
| 19 | Hand off | **pollinate** | Transfer material from one tree to another |
| 20 | Merge | **harvest** | Gather the mature fruit into the main store |
| 21 | Work tracker | **Almanac** | Seasonal record of planting, growth, and harvest |
| 22 | Expertise store | **Humus** | Deep, rich, accumulated organic knowledge |
| 23 | Prompt manager | **Trellis** | Supporting structure that guides growth direction |
| 24 | Communication bus | **Pollen** | Carries information between trees on the wind |
| 25 | Merge queue | **Arbor** | Structured framework where branches are trained and integrated |
| 26 | Quality engine | **Assay** | Testing soil and fruit quality |
| 27 | Browser automation | **Eyespot** | Light-sensing organ in plants (visual observation) |
| 28 | Multi-agent effort | **Thicket** | A dense cluster of trees working together |
| 29 | Project workspace | **Plot** | A dedicated area of the grove for one planting |

#### Example CLI Usage

```bash
gv sow seed-3d1a bough-backend       # dispatch task to backend team lead
gv ring thicket-12                    # check status of multi-agent effort
gv compost sapling-ui --humus=design  # load design expertise into UI worker
gv harvest plot-api                   # merge completed work in api project
```

#### Example Conversation

> "Sow this seed with the backend sapling. The pruner found blight on
> the last graft, so run the assay before it goes to the arbor for
> harvest."

#### Strengths

- **Organic, modern tone:** Solarpunk-adjacent, feels forward-looking. No
  fossil fuel dissonance.
- **Growth metaphor is apt:** Software *does* grow. Seeds become trees.
  Knowledge accumulates like humus. This is not a stretch.
- **Ecosystem coherence:** Every term relates to every other term. Mycelium
  connects to mulch connects to humus connects to compost. The system
  feels alive.

#### Weaknesses

- **Some obscure terms:** Mycorrhiza, humus, rootstock — accessible to
  gardeners, opaque to others. "Eyespot" for browser automation is forced.
- **Overstory overlap:** Borrows from and extends an existing platform's
  theme. Could feel derivative rather than original.
- **Passive connotation:** Forests grow slowly and passively. The platform
  is about fast, active, coordinated work. "Sow a seed" sounds slower
  than "cast an ingot" or "berth some cargo."
- **Naming workers "Sapling":** Implies immaturity and smallness. Agents
  doing real work might feel diminished by the term.

---

### 4.4 Hive — Social Insects

**Metaphor family:** A hive is a superorganism — individual agents with
specialized roles that collectively produce something no single agent could.
Bees have scouts, workers, a coordination dance (waggle), and structured
storage (comb). The parallel to multi-agent AI orchestration is striking:
many specialized agents, coordinated communication, emergent capability.

**Platform name:** Hive
**CLI command:** `hv`

#### Vocabulary Mapping

| # | Concept | Hive Name | Reasoning |
|---|---------|----------|-----------|
| 1 | Platform | **Hive** | A superorganism of coordinated agents |
| 2 | CLI | **`hv`** | Short, distinctive |
| 3 | Atomic task | **Cell** | The basic unit of the comb, holds one piece of work |
| 4 | Workflow template | **Pattern** | The genetic blueprint for a comb structure |
| 5 | Active workflow | **Swarm** | A pattern in motion, agents actively working |
| 6 | Ephemeral workflow | **Flutter** | Brief flight, no permanent comb built |
| 7 | Coordinator | **Queen** | Sets direction, does not do the work directly |
| 8 | Team lead | **Foreman** | Experienced worker directing a cluster |
| 9 | Worker | **Drone** | Agent dedicated to a task (Backend Drone, UI Drone) |
| 10 | Reviewer | **Sentinel** | Guards the entrance, inspects what enters |
| 11 | Merger | **Waggle** | The communication dance that integrates information |
| 12 | Scout | **Scout** | Finds resources, reports back with a waggle |
| 13 | Watchdog | **Ward** | Patrols the hive perimeter, detects threats |
| 14 | Infra helper | **Nurse** | Maintains the hive infrastructure, feeds larvae |
| 15 | Dispatch work | **forage** | Send an agent out to gather/process a cell |
| 16 | Load context | **prime** | Load pollen into the agent before dispatch |
| 17 | Check status | **pulse** | Check the hive's heartbeat |
| 18 | Escalate | **sting** | Emergency response, costs something to deploy |
| 19 | Hand off | **relay** | Trophallaxis — food/data passed mouth to mouth |
| 20 | Merge | **cap** | Seal the cell, work is complete and integrated |
| 21 | Work tracker | **Comb** | The structured grid of all cells and their states |
| 22 | Expertise store | **Nectar** | Concentrated, refined knowledge |
| 23 | Prompt manager | **Pheromone** | Chemical signals that guide behavior patterns |
| 24 | Communication bus | **Dance** | The waggle dance — structured inter-agent messaging |
| 25 | Merge queue | **Chamber** | Where cells are processed and sealed in sequence |
| 26 | Quality engine | **Assay** | Testing the quality of honey/output |
| 27 | Browser automation | **Compound Eye** | Multi-faceted visual observation |
| 28 | Multi-agent effort | **Colony** | The full swarm working a large objective |
| 29 | Project workspace | **Apiary** | A managed location for one or more hives |

#### Example CLI Usage

```bash
hv forage cell-7b2e foreman-backend  # dispatch task to backend team lead
hv pulse colony-12                   # check status of multi-agent effort
hv prime drone-ui --nectar=design    # load design expertise into UI worker
hv cap apiary-api                    # merge completed work in api project
```

#### Example Conversation

> "Forage this cell to the backend drone. The sentinel flagged a defect
> on the last swarm, so run the assay before it goes to the chamber
> for capping."

#### Strengths

- **Perfect structural metaphor:** A hive literally IS a multi-agent
  coordination system. Scouts find work, workers process it, sentinels
  guard quality, the queen coordinates — this is not a stretch, it is
  a direct mapping.
- **Distinctive and memorable:** "Waggle," "forage," "comb," "pheromone"
  are distinctive terms that will not be confused with any other system.
- **Extensible:** Bee/insect vocabulary is vast (larva, pupa, propolis,
  royal jelly, honey, wax, brood, colony collapse, pollination).
- **Energetic tone:** Hives are fast, busy, productive. The metaphor
  implies speed and coordination.

#### Weaknesses

- **"Drone" has baggage:** In common usage, "drone" implies mindless
  or expendable. In actual bee biology, drones are the males who mate
  and die. Neither connotation is ideal for "the agent doing your work."
- **"Queen" gender dynamics:** Some users may find the gendered hierarchy
  term uncomfortable in a professional tool, or may misread it as the
  human operator rather than the coordinator.
- **Entomological barrier:** "Trophallaxis," "pheromone," "compound eye" —
  many terms require biology knowledge that most developers lack.
- **"Hive" collision:** "Hive" is used by Apache Hive, HashiCorp (Hive),
  and numerous other projects. Search results will be polluted.

---

### 4.5 Studio — Creative Production

**Metaphor family:** A studio is where creative work is produced — film,
music, art, architecture. Directors coordinate, crews execute, work goes
through drafts and takes, quality is checked in reviews, and the final
product premieres. This maps cleanly to software: drafts become releases,
directors decompose work, crews build, reviewers provide feedback.

**Platform name:** Studio
**CLI command:** `st`

#### Vocabulary Mapping

| # | Concept | Studio Name | Reasoning |
|---|---------|------------|-----------|
| 1 | Platform | **Studio** | Where creative work is produced |
| 2 | CLI | **`st`** | Short, though conflicts with `st` (Syncthing, some git aliases) |
| 3 | Atomic task | **Take** | One attempt at producing a scene/output |
| 4 | Workflow template | **Script** | A reusable blueprint for a production |
| 5 | Active workflow | **Scene** | A script in active production |
| 6 | Ephemeral workflow | **Improv** | Unscripted, not preserved in the final cut |
| 7 | Coordinator | **Director** | Shapes the vision, sequences the work |
| 8 | Team lead | **Producer** | Manages resources, keeps the workstream on track |
| 9 | Worker | **Crew** | The ones building (Lighting Crew, Sound Crew, Set Crew) |
| 10 | Reviewer | **Critic** | Evaluates quality, provides structured feedback |
| 11 | Merger | **Editor** | Cuts, combines, and sequences the final product |
| 12 | Scout | **Location Scout** or **Scout** | Finds the right setting/context for the work |
| 13 | Watchdog | **Stage Manager** | Monitors everything backstage, keeps it running |
| 14 | Infra helper | **Grip** | Handles equipment, logistics, physical setup |
| 15 | Dispatch work | **call** | "Calling" the scene — directing crew to start |
| 16 | Load context | **brief** | The creative brief that sets up the work |
| 17 | Check status | **check** | "Check the gate" — is the take good? |
| 18 | Escalate | **cut** | Stop everything, something needs attention |
| 19 | Hand off | **wrap** | This station is done, move to post-production |
| 20 | Merge | **final cut** or **print** | Locked, approved, integrated |
| 21 | Work tracker | **Slate** | The clapperboard that tracks scene/take numbers |
| 22 | Expertise store | **Archive** | Past productions, reference material |
| 23 | Prompt manager | **Playbook** | Directions and cues for how to perform |
| 24 | Communication bus | **Intercom** | Real-time crew communication |
| 25 | Merge queue | **Screening Room** | Where takes are reviewed and approved in sequence |
| 26 | Quality engine | **Dailies** | Daily review of all footage/output |
| 27 | Browser automation | **Monitor** | The screen where you watch the output |
| 28 | Multi-agent effort | **Production** | A full-scale coordinated effort |
| 29 | Project workspace | **Stage** | A dedicated space for one production |

#### Example CLI Usage

```bash
st call take-9c4d producer-backend   # dispatch task to backend team lead
st check production-12               # check status of multi-agent effort
st brief crew-ui --archive=design    # load design expertise into UI worker
st print stage-api                   # merge completed work in api project
```

#### Example Conversation

> "Call this take to the backend crew. The critic flagged issues in the
> last scene's dailies, so make sure it passes the screening room
> before the final cut."

#### Strengths

- **Immediately accessible:** Everyone understands director, crew, script,
  scene, take. Near-zero learning curve.
- **Rich verb vocabulary:** Call, cut, wrap, print, brief, check — all
  are real production terms AND intuitive CLI commands.
- **Professional and creative:** Strikes a balance between serious (this
  is a production) and engaging (creative work is exciting).
- **Natural workflow mapping:** Productions literally follow the same
  flow as software: plan (script) -> produce (takes) -> review (dailies)
  -> integrate (edit) -> release (premiere).

#### Weaknesses

- **"Studio" is overloaded:** Android Studio, Visual Studio, FL Studio,
  Roblox Studio. The word is extremely common in software.
- **`st` conflicts:** Several tools use `st` as a command or alias.
- **"Crew" is vague:** Like Overstory's "Builder," it does not specify
  what kind of work. "Backend Crew" is just `{domain}-crew`.
- **Some terms feel forced:** "Grip" for infrastructure helper works in
  film but requires film knowledge. "Dailies" for quality engine is
  clever but obscure.
- **Scale mismatch:** Film productions have one director, one editor.
  The platform may run dozens of concurrent directors. The metaphor
  implies singular hierarchy.

---

## 5. Side-by-Side Comparison Table

All 29 concepts mapped across all 5 candidates.

| # | Concept | Forge | Harbor | Grove | Hive | Studio |
|---|---------|-------|--------|-------|------|--------|
| 1 | Platform | Forge | Harbor | Grove | Hive | Studio |
| 2 | CLI | `fg` | `hb` | `gv` | `hv` | `st` |
| 3 | Atomic task | Ingot | Cargo | Seed | Cell | Take |
| 4 | Workflow template | Mold | Manifest | Rootstock | Pattern | Script |
| 5 | Active workflow | Pour | Voyage | Graft | Swarm | Scene |
| 6 | Ephemeral workflow | Spark | Ferry | Spore | Flutter | Improv |
| 7 | Coordinator | Crucible | Harbormaster | Canopy | Queen | Director |
| 8 | Team lead | Anvil | Pilot | Bough | Foreman | Producer |
| 9 | Worker | Smith | Crew | Sapling | Drone | Crew |
| 10 | Reviewer | Assayer | Inspector | Pruner | Sentinel | Critic |
| 11 | Merger | Alloy | Dock | Taproot | Waggle | Editor |
| 12 | Scout | Prospector | Lookout | Tendril | Scout | Scout |
| 13 | Watchdog | Sentinel | Lighthouse | Mycelium | Ward | Stage Manager |
| 14 | Infra helper | Bellows | Tugboat | Mulch | Nurse | Grip |
| 15 | Dispatch | cast | berth | sow | forage | call |
| 16 | Load context | heat | ballast | compost | prime | brief |
| 17 | Check status | gauge | signal | ring | pulse | check |
| 18 | Escalate | quench | mayday | blight | sting | cut |
| 19 | Hand off | pass | tow | pollinate | relay | wrap |
| 20 | Merge | temper | moor | harvest | cap | print |
| 21 | Work tracker | Ledger | Logbook | Almanac | Comb | Slate |
| 22 | Expertise store | Lore | Charts | Humus | Nectar | Archive |
| 23 | Prompt manager | Patterns | Signals | Trellis | Pheromone | Playbook |
| 24 | Comms bus | Herald | Channel | Pollen | Dance | Intercom |
| 25 | Merge queue | Annealer | Lock | Arbor | Chamber | Screening Room |
| 26 | Quality engine | Assay | Customs | Assay | Assay | Dailies |
| 27 | Browser automation | Lens | Periscope | Eyespot | Compound Eye | Monitor |
| 28 | Multi-agent effort | Commission | Fleet | Thicket | Colony | Production |
| 29 | Project workspace | Foundry | Berth | Plot | Apiary | Stage |

---

## 6. Scoring Matrix

Each candidate scored 1-5 on each criterion, multiplied by criterion weight.

### Raw Scores (1-5)

| Criterion | Weight | Forge | Harbor | Grove | Hive | Studio |
|-----------|--------|-------|--------|-------|------|--------|
| Vocabulary depth | 5 | 5 | 5 | 4 | 4 | 4 |
| Function-telegraphing | 5 | 4 | 4 | 3 | 4 | 5 |
| Memorability | 4 | 4 | 3 | 4 | 5 | 3 |
| Learnability | 4 | 3 | 4 | 3 | 3 | 5 |
| Extensibility | 3 | 4 | 5 | 4 | 4 | 3 |
| Search-friendliness | 3 | 3 | 2 | 4 | 2 | 1 |
| Tone | 3 | 4 | 3 | 4 | 4 | 4 |

### Weighted Scores (raw x weight)

| Criterion | Weight | Forge | Harbor | Grove | Hive | Studio |
|-----------|--------|-------|--------|-------|------|--------|
| Vocabulary depth | 5 | 25 | 25 | 20 | 20 | 20 |
| Function-telegraphing | 5 | 20 | 20 | 15 | 20 | 25 |
| Memorability | 4 | 16 | 12 | 16 | 20 | 12 |
| Learnability | 4 | 12 | 16 | 12 | 12 | 20 |
| Extensibility | 3 | 12 | 15 | 12 | 12 | 9 |
| Search-friendliness | 3 | 9 | 6 | 12 | 6 | 3 |
| Tone | 3 | 12 | 9 | 12 | 12 | 12 |
| **TOTAL** | **27** | **106** | **103** | **99** | **102** | **101** |

### Score Summary

| Rank | Theme | Score | Top Strength | Top Weakness |
|------|-------|-------|-------------|-------------|
| 1 | **Forge** | 106 | Vocabulary depth + creation metaphor | "Forge" name collision |
| 2 | **Harbor** | 103 | Extensibility + coordination metaphor | "Harbor" name collision, bureaucratic tone |
| 3 | **Hive** | 102 | Memorability + structural parallel | "Drone" and "Queen" connotations, name collision |
| 4 | **Studio** | 101 | Learnability + function-telegraphing | "Studio" massively overloaded, poor searchability |
| 5 | **Grove** | 99 | Search-friendliness + cohesive ecosystem | Passive connotation, some forced terms |

The scores are tightly clustered (99-106 out of a possible 135), indicating
that all five themes are viable. The decision will come down to qualitative
factors and team preference, not a clear quantitative winner.

---

## 7. Recommendation Methodology

### Do Not Choose Yet

The naming decision is too consequential and too subjective for a spreadsheet
to resolve. The scoring matrix narrows the field but does not pick the winner.
Here is the process for reaching a final decision.

### Step 1: Identify Dealbreakers

Before comparing themes, eliminate any with hard disqualifiers.

| Dealbreaker | Affected Themes | Severity |
|-------------|----------------|----------|
| Name collision with a major existing product | Harbor (Harbor container registry), Hive (Apache Hive), Studio (Visual Studio, Android Studio) | Medium-High |
| Gender-loaded role names | Hive (Queen) | Low-Medium (mitigatable by renaming to "Monarch") |
| Passive/slow connotation for an orchestration tool | Grove | Low-Medium |
| `st` CLI conflicts with common aliases | Studio | Low |

**Assessment:** No theme has a hard dealbreaker, but Harbor, Hive, and Studio
carry name collision risk. Forge has a lighter collision (GitHub Forge was
discontinued; Atlassian Forge is a niche product). Grove has the cleanest
namespace.

### Step 2: Shortlist 2-3 Candidates

Based on scores and dealbreaker analysis, the recommended shortlist:

1. **Forge** — Highest score, creation-focused, professional tone. Manageable
   name collision risk.
2. **Hive** — Highest memorability, best structural metaphor. "Drone" can be
   renamed (Agent? Bee? Worker Bee?). "Queen" can become "Monarch."
3. **Harbor** — Strongest extensibility, natural coordination metaphor. Name
   collision is the main concern.

**Alternates:** Grove if the team values search-friendliness and ecological
tone. Studio if learnability is the top priority (lowest learning curve of all
candidates).

### Step 3: Test With Real CLI Usage

For each shortlisted theme, write out 20 realistic CLI commands covering
the full range of daily operations. Evaluate:

- Do the commands feel natural to type repeatedly?
- Can you guess what a command does from reading it cold?
- Do any two terms feel confusingly similar?
- Does the 2-letter CLI prefix feel right under the fingers?

Example test battery:

```bash
# Morning standup: what happened overnight?
fg gauge --all                       # Forge
hv pulse --all                       # Hive
hb signal --all                      # Harbor

# Dispatch a new task to a backend worker
fg cast ingot-new anvil-backend      # Forge
hv forage cell-new foreman-backend   # Hive
hb berth cargo-new pilot-backend     # Harbor

# Something is stuck, escalate it
fg quench ingot-4a2f                 # Forge
hv sting cell-4a2f                   # Hive
hb mayday cargo-4a2f                 # Harbor

# Merge the completed work
fg temper foundry-api                # Forge
hv cap apiary-api                    # Hive
hb moor berth-api                    # Harbor
```

### Step 4: Test With Real Conversation

Have team members describe platform operations using each theme's vocabulary
in spoken conversation. Does it feel natural or forced?

> **Forge:** "The assayer rejected the last pour. I recast the ingot to a
> different smith and it passed assay on the second attempt."
>
> **Hive:** "The sentinel rejected the last swarm. I reforged the cell to
> a different drone and it passed assay on the second attempt."
>
> **Harbor:** "Customs rejected the last voyage. I reberthed the cargo with
> a different crew and it cleared customs on the second attempt."

### Step 5: Validate Extensibility

List 5 concepts the platform does not have today but might add in v2-v3.
Can each theme name them naturally?

| Future Concept | Forge | Hive | Harbor |
|---------------|-------|------|--------|
| Cost tracking / billing | Mint | Royal Jelly | Tariff |
| Plugin/extension system | Attachment | Symbiont | Cargo Module |
| Multi-repo orchestration | Federation | Megacolony | Armada |
| Rollback / undo | Reforge | Molt | Recall |
| User permissions / RBAC | Guild Rank | Caste | Port Authority |

### Step 6: Make the Call

After steps 3-5, the team should have a visceral sense of which theme
they *want* to use daily. Trust that instinct — it encodes the learnability,
tone, and memorability criteria better than any matrix.

The final naming decision should satisfy three non-negotiable requirements:

1. **The platform name is available** as a domain, GitHub org, and npm/PyPI
   package (or close variants).
2. **The CLI command does not conflict** with widely-used tools in the
   target user's likely environment.
3. **The team is excited to use the names.** A naming system that scores
   perfectly but that nobody enjoys typing is a failure.

---

## Appendix A: Lessons From the Five Source Platforms

What each existing platform teaches about naming:

| Platform | Lesson | Evidence |
|----------|--------|----------|
| Gas Town | A strong theme creates unforgettable identity but can alienate newcomers | Users must learn Mad Max to understand the system |
| Overstory | Ecosystem coherence matters more than individual term quality | Seeds/Mulch/Canopy form a system; Coordinator/Lead/Builder do not |
| gstack | Function-as-name has the lowest learning curve | `/review` `/ship` `/qa` — self-documenting commands |
| ATSA | Neutral naming works functionally but creates no identity | `backend-agent` is clear but forgettable; no one gets excited about it |
| Beads | A single strong metaphor (string of beads) can anchor an entire work system | But overloading the metaphor (Beads the system vs. bead the work unit) creates ambiguity |

### The Sweet Spot

The ideal naming system combines:

- **Gas Town's commitment** to a fully-realized theme (not half-measures)
- **Overstory's ecosystem coherence** (terms reinforce each other)
- **gstack's function-telegraphing** (names hint at what they do)
- **ATSA's consistency** (predictable naming patterns)
- **Beads' simplicity** (one core metaphor everything hangs from)

No existing platform achieves all five. The candidate themes above attempt to.

---

## Appendix B: Anti-Patterns to Avoid

Naming mistakes observed across the five source platforms:

1. **The Overloaded Name.** Beads uses "bead" for both the system name and
   the atomic work unit. Avoid naming the platform the same as any internal
   concept.

2. **The Insider Reference.** Gas Town's "Polecat" requires watching Mad Max:
   Fury Road to understand. Every name should be guessable from general
   vocabulary.

3. **The Generic Name.** Overstory's "Coordinator," "Lead," "Builder" are
   functional but forgettable. If removing the theme leaves the name
   unchanged, the theme is not working.

4. **The Forced Metaphor.** A theme stretched past its natural limits produces
   terms like "Eyespot" (Grove's browser automation) or "Compound Eye"
   (Hive's browser automation). When a metaphor cannot supply a natural term,
   use a neutral fallback rather than forcing.

5. **The Collision.** Names that collide with popular existing tools create
   search pollution and user confusion. Check: GitHub projects, npm packages,
   Wikipedia articles, common CLI commands.

6. **The Abbreviation Trap.** Two-letter CLI commands are convenient but the
   namespace is crowded. Check against: `ls`, `cd`, `rm`, `cp`, `mv`, `ps`,
   `df`, `du`, `wc`, `bc`, `dc`, `fc`, `fg` (foreground!), `bg`, `nl`,
   `od`, `pr`, `pt`, `sc`, `sh`, `su`, `tr`, `vi`. Note: `fg` (Forge)
   conflicts with the shell's foreground command. This would need to be
   changed to `fo` or `fr`.

7. **The Mood Mismatch.** Gas Town's post-apocalyptic theme implies scarcity,
   desperation, and decay. The platform is about productivity, growth, and
   coordination. Theme mood should match product mood.

---

## Appendix C: CLI Command Conflict Check

| Theme | Proposed CLI | Conflicts | Alternative |
|-------|-------------|-----------|-------------|
| Forge | `fg` | `fg` is a POSIX shell built-in (foreground) | `fo`, `fr`, `fge` |
| Harbor | `hb` | No known conflicts | (none needed) |
| Grove | `gv` | No known conflicts | (none needed) |
| Hive | `hv` | No known conflicts | (none needed) |
| Studio | `st` | Syncthing CLI, some git aliases | `su` (conflict with su), `sd` (conflict with Seeds) |

**Critical finding:** Forge's `fg` conflicts with the POSIX `fg` command
(resume a backgrounded process). This is a significant practical issue —
users who background processes with Ctrl-Z cannot type `fg` to resume them.
Forge would need to use `fo` or another prefix.
