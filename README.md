# Lafly — Native macOS AI Agent Voice Assistant

<div align="center">
  <h3>Autonomous Voice-First AI Agent for macOS</h3>
  <p>Wake Phrase: <b>"Woi Lafly"</b> • Development Fallback Hotkey: <b>⌥ + Space (Option + Space)</b></p>
  <p>Natively supports <b>Indonesian</b>, <b>English</b>, and <b>Indonesian-English code switching</b>.</p>
</div>

---

## 1. Overview

**Lafly** is a native macOS AI assistant inspired by Siri, engineered from the ground up as an **autonomous agent** capable of understanding voice commands, operating macOS, navigating apps, controlling Terminal with safety guarantees, doing web research, and executing multi-step workflows.

### Core Philosophy:
* **The LLM does NOT control the computer directly.** The LLM only decides what actions are needed and with what parameters.
* **Separation of Concerns:** A dedicated local `ToolExecutor` validates parameters, checks security permissions, prompts user confirmation for sensitive/dangerous actions, and executes native macOS APIs.
* **Non-destructive by default:** Destructive commands (e.g. `rm -rf /`, fork bombs, disk overwriting) are strictly blocked at the safety layer.

---

## 2. Architecture

```text
┌────────────────────────────────────────────────────────┐
│             Native macOS App (Swift / SwiftUI)         │
│  - Menu Bar Item (NSStatusItem)                        │
│  - Floating Assistant Overlay (Siri-style glassmorphism)│
│  - Microphone (AVAudioEngine) & Native TTS (AVSpeech)  │
│  - Option + Space Global Hotkey Listener               │
│  - Permission Checkers (Accessibility, Microphone)     │
└──────────────────────────┬─────────────────────────────┘
                           │ (HTTP REST / WebSocket at ws://127.0.0.1:3847/ws)
┌──────────────────────────▼─────────────────────────────┐
│              Agent Runtime Daemon (Node.js)            │
│  - Multi-step Agent Loop (AgentRuntime)                │
│  - Bilingual Prompt Engine (Indonesian & English)      │
│  - Structured Logging & Key Redaction                  │
│  - Memory Store (Preferences, Facts, Tasks)            │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│               Tool Registry & Executor                 │
│  - Side-Effect Gate (none/reversible/external/destr.)  │
│  - Permission Enforcement (SAFE / SENSITIVE / DANGEROUS)│
│  - Terminal Command Safety Inspector                   │
│  - Confirmation Hooks & Interactive UI Dialogs         │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                    macOS System Layer                  │
│  - CoreGraphics / AppleScript / System Events          │
│  - NSWorkspace / screencapture / Filesystem APIs       │
└────────────────────────────────────────────────────────┘
```

---

## 3. Project Structure

```text
lafly/
├── apps/
│   ├── macos/                     # Native macOS Swift/SwiftUI application
│   │   ├── Package.swift          # SPM package configuration (macOS 14+)
│   │   └── Sources/LaflyApp/     # Overlay, MenuBar, Audio, Hotkey, Client
│   └── agent/                     # Local Node.js agent runtime daemon
│       └── src/                   # HTTP REST server, WebSocket broadcaster
│
├── packages/
│   ├── types/                     # Shared TypeScript contracts & schemas
│   ├── config/                    # Environment & runtime configuration loader
│   ├── tools/                     # Tool definitions, registry & safety inspector
│   └── core/                      # Agent loop, LLM/TTS/STT providers, memory
│
├── scripts/                       # build.sh, start-agent.sh, run-macos.sh
│   └── migration/                 # one-off rename record (not runtime code)
├── tests/                         # MVP acceptance, safe testing, rebrand validation
├── vitest.config.ts               # Test runner config (pins safe test mode)
├── .env.example                   # Environment variable template
└── package.json                   # Root monorepo workspace configuration
```

---

## 4. Built-in Tools

| Tool | Permission | Side effect | Description |
| :--- | :--- | :--- | :--- |
| `open_app(appName)` | `SAFE` | `reversible` | Launches or brings an app to the foreground via `open -a` / AppleScript. |
| `close_app(appName)` | `SAFE` | `reversible` | Gracefully quits an application. |
| `screenshot()` | `SAFE` | `none` | Captures the screen via macOS `screencapture` silently. |
| `click(x, y)` | `SENSITIVE` | `external` | Simulates native mouse left click via CoreGraphics event tap. |
| `double_click(x, y)` | `SENSITIVE` | `external` | Simulates native mouse double click via CoreGraphics event tap. |
| `move_mouse(x, y)` | `SAFE` | `reversible` | Moves cursor position without clicking. |
| `scroll(direction, amount)` | `SAFE` | `reversible` | Simulates mouse wheel scrolling (up, down, left, right). |
| `type_text(text)` | `SENSITIVE` | `external` | Types keystrokes into the active application via AppleScript. |
| `press_key(key, modifiers)` | `SENSITIVE` | `external` | Presses special keys (return, escape, space, tab, up, down). |
| `read_file(path)` | `SAFE` | `none` | Reads file content safely with size limits. |
| `write_file(path, content)` | `SENSITIVE` | `reversible` | Writes text content, creating directories as needed. |
| `delete_file(path)` | `DANGEROUS` | `destructive` | Deletes a file or directory. |
| `run_command(command)` | `SENSITIVE` / `DANGEROUS` | `destructive` | Executes shell commands with strict safety inspection. |
| `web_search(query)` | `SAFE` | `external` | Searches the web using DuckDuckGo. |
| `open_url(url)` | `SAFE` | `external` | Opens URLs in default web browser via macOS `open`. |
| `read_web_page(url)` | `SAFE` | `external` | Fetches and extracts clean readable text from web pages. |
| `send_whatsapp_message(recipient, message)` | `SENSITIVE` | `external` | Sends a message, preserving the payload verbatim. |

A tool that does not declare a side effect is treated as `external`, so a newly
added tool can never inherit a permissive default by accident.

---

## 5. Security & Permission Tiers

* **`SAFE`**: Read-only operations, web search, screenshots, safe app opening. Executes directly.
* **`SENSITIVE`**: Modifying files, standard terminal commands, message sending. Prompts user confirmation by default.
* **`DANGEROUS`**: Destructive shell commands, system restarts, superuser commands. Requires explicit user confirmation.
* **`BLOCKED`**: Catastrophic commands (e.g. `rm -rf /`, `:(){ :|:& };:`, raw disk writes `dd of=/dev/rdisk0`) are unconditionally blocked.

---

## 6. Safe Testing & Side-Effect Protection

Lafly can send WhatsApp messages, delete files, type into your frontmost
application, and run shell commands. Development and test runs must never do
that by accident, so side effects are gated **below the LLM** — a system prompt
or a model response cannot talk its way past the executor.

### Execution modes

| Mode | What happens |
| :--- | :--- |
| `dry_run` (default) | Tools are simulated. Arguments are validated and echoed back, but nothing external happens. |
| `sandbox` | Sandbox-capable tools execute against `LAFLY_SANDBOX_ROOT` instead of your real files. Destructive tools stay simulated. |
| `live` | Real side effects. Requires an explicit, deliberate opt-in. |

```bash
pnpm test          # always safe
pnpm dev           # safe by default
pnpm dev:live      # deliberate live execution
```

### Configuration

```env
LAFLY_ENV=development
SAFE_TEST_MODE=true
LIVE_SIDE_EFFECTS=false
LAFLY_EXECUTION_MODE=dry_run
LAFLY_SANDBOX_ROOT=~/LaflySandbox
```

### Rules

* **Safe by default.** An unset, unparseable, or ambiguous value resolves to `dry_run`.
* **Fail closed.** `SAFE_TEST_MODE=true` together with `LIVE_SIDE_EFFECTS=true` is a configuration error and still resolves to `dry_run`.
* **CI can never go live.** `LIVE_SIDE_EFFECTS=true` under CI is rejected at runtime.
* **Every simulated result is labelled.** Results carry `mode`, `dryRun`, and `executed`, so a simulation can never be mistaken for a real action:

  ```json
  {
    "success": true,
    "dry_run": true,
    "executed": false,
    "recipient": "Reja Agung",
    "message": "Yuli bubur"
  }
  ```

* **Tests are pinned.** `tests/setup.ts` forces dry-run mode before any test
  module loads, so a tool that forgot to check the policy still cannot execute.

### Trying a command without sending anything

```bash
curl -s -X POST http://127.0.0.1:3847/query \
  -H 'Content-Type: application/json' \
  -d '{"text":"WhatsApp Reja Agung terus bilang Yuli bubur"}' | jq
```

The response reports the intended recipient and the verbatim message with
`executed: false`. The full pipeline — parser, recipient extraction, message
extraction, validation, executor routing — runs exactly as it would in
production. Only the delivery is skipped.

---

## 7. Getting Started

### Prerequisites:
* macOS (Sonoma 14+ or Sequoia 15+)
* Node.js v20+ (tested on Node v26)
* pnpm v9+
* Swift 5.9+ / Xcode command line tools

### Installation:
```bash
git clone git@github.com:dynrbni/lafly.git
cd lafly
pnpm install
```

### Configuration:
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

#### 9Router Setup & Configuration:

Lafly integrates with local **9Router** (`http://localhost:20128/v1`) using an OpenAI-compatible interface and defaults to `ag/gemini-3.8-flash-high`.

1. **Start 9Router**: Ensure your local 9Router server is running at `http://localhost:20128/v1`.
2. **Configure the provider/model in 9Router**: Add your upstream provider (e.g., Gemini) and configure model `ag/gemini-3.8-flash-high`.
3. **Copy the API key** generated in 9Router.
4. **Put the API key into `.env`**:
   ```env
   NINEROUTER_BASE_URL=http://localhost:20128/v1
   NINEROUTER_API_KEY=your_actual_key_here
   NINEROUTER_MODEL=ag/gemini-3.8-flash-high
   ```
5. **Start Lafly**:
   ```bash
   ./scripts/start-agent.sh
   ./scripts/run-macos.sh
   ```
6. **Test with voice or text**:
   ```text
   "Buka Spotify"
   ```

#### Environment Variables:
* `NINEROUTER_BASE_URL`: OpenAI-compatible endpoint URL for 9Router (defaults to `http://localhost:20128/v1`).
* `NINEROUTER_API_KEY`: API key used to authenticate with 9Router (keep blank in git; configure only in local `.env`).
* `NINEROUTER_MODEL`: LLM model identifier routed through 9Router (defaults to `ag/gemini-3.8-flash-high`).


### Build:
```bash
./scripts/build.sh
```

### Run Tests:
```bash
pnpm test
```

### Launching:
1. Start the Agent Daemon:
```bash
./scripts/start-agent.sh
```

2. Launch the native macOS app:
```bash
./scripts/run-macos.sh
```

Activate Lafly anytime with the development hotkey: **`Option + Space`** or via the menu bar item.

---

## 8. MVP Acceptance Scenarios

| Scenario | Input | Expected Output | Status |
| :--- | :--- | :--- | :--- |
| **Test 1** | `"Woi Lafly"` / Hotkey | Lafly activates and enters `listening` state. | Verified |
| **Test 2** | `"What time is it?"` | Answers the current time with voice (TTS). | Verified |
| **Test 3** | `"Buka Spotify."` | Invokes `open_app(Spotify)`. | Verified |
| **Test 4** | `"Buka Safari."` | Invokes `open_app(Safari)`. | Verified |
| **Test 5** | `"Ambil screenshot."` | Screenshot captured and saved to disk. | Verified |
| **Test 6** | `"Buka Terminal dan jalankan pwd."` | Evaluates safety & asks for confirmation before executing. | Verified |
| **Test 7** | `"Buka Spotify dan cari Bruno Mars."` | Multi-step tool pipeline (`open_app` -> `type_text` -> `press_key`). | Verified |

---

## 9. Git & GitHub Branching Model

* `main` — Production-ready, stable releases.
* `development` — Integration branch for completed feature branches.
* `feat/*` — Dedicated feature branches (e.g., `feat/monorepo-foundation`, `feat/tool-system`, `feat/agent-core`, `feat/agent-server`, `feat/macos-app`, `feat/mvp-acceptance-integration`).
