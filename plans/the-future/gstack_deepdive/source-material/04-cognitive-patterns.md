# 04 — Cognitive Patterns

## The Core Idea

Instead of checklists ("check for SQL injection, check for XSS, check for..."),
gstack's review skills activate **latent knowledge of how great leaders think**.
The instruction is "internalize these, don't enumerate them" — making each review
a genuine perspective shift, not a longer checklist.

This works because LLMs have deep knowledge of these thinkers and their frameworks.
Invoking "think like Andy Grove" activates a coherent worldview, not just a bullet point.

## CEO Mode — 14 Patterns (`/plan-ceo-review`)

| Pattern | Thinker | Core Insight |
|---------|---------|-------------|
| Bezos Doors | Jeff Bezos | One-way doors (irreversible) need caution; two-way doors (reversible) need speed |
| Day 1 Proxy | Jeff Bezos | Skepticism toward process-as-proxy — process should serve customers, not itself |
| Regret Minimization | Jeff Bezos | Will you regret NOT doing this in 10 years? |
| Grove Paranoid Scanning | Andy Grove | "Only the paranoid survive" — what threat are you not seeing? |
| Munger Inversion | Charlie Munger | Invert the problem — what would guarantee failure? Avoid that. |
| Munger Latticework | Charlie Munger | Apply mental models from multiple disciplines |
| Horowitz Wartime/Peacetime | Ben Horowitz | Peacetime: expand, explore. Wartime: focus, cut, survive. |
| Chesky Founder Mode | Brian Chesky | Founders should stay close to product details, not delegate blindly |
| Altman Leverage | Sam Altman | What's the highest-leverage thing you could do right now? |
| Collison Stripe Think | Patrick Collison | Think clearly about hard problems, don't pattern-match |
| Lütke Shopify Scale | Tobi Lütke | Build for the next 10x scale, not the current one |
| Graham Schlep Blindness | Paul Graham | The most valuable work is often the work nobody wants to do |
| Thiel Zero to One | Peter Thiel | Are you creating something new or copying what exists? |
| Tan Founder Density | Garry Tan | High-density teams (small, elite) outperform large teams |

### 4 Operating Modes

The CEO review offers 4 modes the user chooses:
1. **SCOPE EXPANSION** — Dream big, surface all opportunities enthusiastically
2. **SELECTIVE EXPANSION** — Hold current scope, cherry-pick expansion opportunities
3. **HOLD SCOPE** — Maximum rigor on existing plan
4. **SCOPE REDUCTION** — Minimal viable version

## Eng Mode — 15 Patterns (`/plan-eng-review`)

| Pattern | Thinker/Source | Core Insight |
|---------|---------------|-------------|
| Larson Team State | Will Larson | Diagnose team state: falling behind, treading water, repaying debt, or innovating |
| McKinley Boring Default | Dan McKinley | Choose boring technology — new tech has hidden costs |
| Brooks Essential/Accidental | Fred Brooks | Distinguish essential complexity (inherent) from accidental (self-inflicted) |
| Beck Make Change Easy | Kent Beck | "Make the change easy, then make the easy change" |
| Majors Own Your Code | Charity Majors | You should run what you build, in production, yourself |
| Google SRE Error Budgets | Google | Error budgets balance reliability and velocity — spend them wisely |
| Fowler Refactoring | Martin Fowler | Continuous small refactors prevent big rewrites |
| Hyrum's Law | Hyrum Wright | Any observable behavior will be depended upon by someone |
| Conway's Law | Melvin Conway | System architecture mirrors communication structure |
| Kernighan Debugging | Brian Kernighan | "Debugging is twice as hard as writing code. If you write code as cleverly as possible, you are by definition not smart enough to debug it." |
| Unix Philosophy | Doug McIlroy | Do one thing well. Compose via pipes. Text as universal interface. |
| Knuth Premature Optimization | Donald Knuth | "Premature optimization is the root of all evil" |
| Postel's Law | Jon Postel | "Be liberal in what you accept, conservative in what you send" |
| Chesterton's Fence | G.K. Chesterton | Before removing something, understand why it was put there |
| Dijkstra Simplicity | Edsger Dijkstra | "Simplicity is prerequisite for reliability" |

### Output Format

The eng review produces:
- Architecture diagrams (ASCII — forces LLMs to think more completely when drawing)
- Data flow diagrams
- State machines
- Edge case analysis
- Test matrices
- Interactive walkthrough: 4 sections × 1 issue per AskUserQuestion

## Design Mode — 12 Patterns (`/plan-design-review`)

| Pattern | Thinker | Core Insight |
|---------|---------|-------------|
| Rams Subtraction | Dieter Rams | "Less, but better." Start by removing. |
| Norman 3 Levels | Don Norman | Visceral (5s), Behavioral (5min), Reflective (5yr) |
| Zhuo Principled Taste | Julie Zhuo | Good design isn't subjective — it's principled judgment |
| Gebbia Trust Design | Joe Gebbia | Design for trust first, features second (Airbnb insight) |
| Ive Care Is Visible | Jony Ive | Users can feel when designers cared about details |
| Tufte Data-Ink | Edward Tufte | Maximize the data-ink ratio — every pixel should mean something |
| Krug Don't Make Me Think | Steve Krug | If users have to think, the design is wrong |
| Victor Immediate Feedback | Bret Victor | The gap between action and result should be zero |
| Chimero Shape of Design | Frank Chimero | Design is about relationships between elements, not individual elements |
| Eames Constraints | Charles Eames | "Design depends largely on constraints" |
| Müller-Brockmann Grid | Josef Müller-Brockmann | Grid systems bring order, proportion, and rhythm |
| Munari Simplicity | Bruno Munari | "Complicating is easy, simplifying is hard" |

### Output: 80-Item Design Audit

10 categories × 8 items each:
1. Visual hierarchy & layout
2. Typography
3. Color system
4. Spacing & rhythm
5. Interactive elements
6. Responsive design
7. Motion & animation
8. Content quality
9. AI slop detection
10. Performance perception

## Why Cognitive Patterns > Checklists

1. **Coherent worldviews** — "Think like Dieter Rams" activates a whole design
   philosophy, not 5 bullet points. The LLM fills in hundreds of implications.

2. **Context-sensitive** — A checklist says "check contrast ratios." A cognitive
   pattern says "would Tufte consider this pixel justified?" The pattern adapts
   to the specific situation.

3. **Composable** — Patterns interact. Bezos Doors + Altman Leverage = "Is this
   a reversible high-leverage bet? Ship it fast."

4. **Memorable** — Engineers remember "Chesterton's Fence" and apply it forever.
   Nobody remembers item 47 on a 200-item checklist.

5. **Upgradable** — Adding a new pattern (e.g., "Carmack's deep focus") enriches
   all future reviews. Adding a checklist item adds one check.
