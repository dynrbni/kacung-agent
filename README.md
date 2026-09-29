# Kacung — Native macOS AI Agent Voice Assistant

<div align="center">
  <h3>Autonomous Voice-First AI Agent for macOS</h3>
  <p>Wake Phrase: <b>"Woi Kacung"</b> • Development Fallback Hotkey: <b>⌥ + Space (Option + Space)</b></p>
  <p>Natively supports <b>Indonesian</b>, <b>English</b>, and <b>Indonesian-English code switching</b>.</p>
</div>

---

## 1. Overview

**Kacung** is a native macOS AI assistant inspired by Siri, engineered from the ground up as an **autonomous agent** capable of understanding voice commands, operating macOS, navigating apps, controlling Terminal with safety guarantees, doing web research, and executing multi-step workflows.

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
kacung/
├── apps/
│   ├── macos/                     # Native macOS Swift/SwiftUI application
│   │   ├── Package.swift          # SPM package configuration (macOS 14+)
│   │   └── Sources/KacungApp/     # Overlay, MenuBar, Audio, Hotkey, Client
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
├── tests/                         # End-to-end MVP acceptance tests (Scenarios 1-7)
├── .env.example                   # Environment variable template
└── package.json                   # Root monorepo workspace configuration
```

---

## 4. Built-in Tools

| Tool | Permission | Description |
| :--- | :--- | :--- |
| `open_app(appName)` | `SAFE` | Launches or brings an app to the foreground via `open -a` / AppleScript. |
| `close_app(appName)` | `SAFE` | Gracefully quits an application. |
| `screenshot()` | `SAFE` | Captures the screen via macOS `screencapture` silently. |
| `click(x, y)` | `SENSITIVE` | Simulates native mouse left click via CoreGraphics event tap. |
| `double_click(x, y)` | `SENSITIVE` | Simulates native mouse double click via CoreGraphics event tap. |
| `move_mouse(x, y)` | `SAFE` | Moves cursor position without clicking. |
| `scroll(direction, amount)` | `SAFE` | Simulates mouse wheel scrolling (up, down, left, right). |
| `type_text(text)` | `SENSITIVE` | Types keystrokes into the active application via AppleScript. |
| `press_key(key, modifiers)` | `SENSITIVE` | Presses special keys (return, escape, space, tab, up, down). |
| `read_file(path)` | `SAFE` | Reads file content safely with size limits. |
| `write_file(path, content)` | `SENSITIVE` | Writes text content, creating directories as needed. |
| `run_command(command)` | `SENSITIVE` / `DANGEROUS` | Executes shell commands with strict safety inspection. |
| `web_search(query)` | `SAFE` | Searches the web using DuckDuckGo. |
| `open_url(url)` | `SAFE` | Opens URLs in default web browser via macOS `open`. |
| `read_web_page(url)` | `SAFE` | Fetches and extracts clean readable text from web pages. |

---

## 5. Security & Permission Tiers

* **`SAFE`**: Read-only operations, web search, screenshots, safe app opening. Executes directly.
* **`SENSITIVE`**: Modifying files, standard terminal commands, message sending. Prompts user confirmation by default.
* **`DANGEROUS`**: Destructive shell commands, system restarts, superuser commands. Requires explicit user confirmation.
* **`BLOCKED`**: Catastrophic commands (e.g. `rm -rf /`, `:(){ :|:& };:`, raw disk writes `dd of=/dev/rdisk0`) are unconditionally blocked.

---

## 6. Getting Started

### Prerequisites:
* macOS (Sonoma 14+ or Sequoia 15+)
* Node.js v20+ (tested on Node v26)
* pnpm v9+
* Swift 5.9+ / Xcode command line tools

### Installation:
```bash
git clone git@github.com:dynrbni/kacung.git
cd kacung
pnpm install
```

### Configuration:
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

#### 9Router Setup & Configuration:

Kacung integrates with local **9Router** (`http://localhost:20128/v1`) using an OpenAI-compatible interface and defaults to `ag/gemini-3.8-flash-high`.

1. **Start 9Router**: Ensure your local 9Router server is running at `http://localhost:20128/v1`.
2. **Configure the provider/model in 9Router**: Add your upstream provider (e.g., Gemini) and configure model `ag/gemini-3.8-flash-high`.
3. **Copy the API key** generated in 9Router.
4. **Put the API key into `.env`**:
   ```env
   NINEROUTER_BASE_URL=http://localhost:20128/v1
   NINEROUTER_API_KEY=your_actual_key_here
   NINEROUTER_MODEL=ag/gemini-3.8-flash-high
   ```
5. **Start Kacung**:
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

Activate Kacung anytime with the development hotkey: **`Option + Space`** or via the menu bar item.

---

## 7. MVP Acceptance Scenarios

| Scenario | Input | Expected Output | Status |
| :--- | :--- | :--- | :--- |
| **Test 1** | `"Woi Kacung"` / Hotkey | Kacung activates and enters `listening` state. | Verified |
| **Test 2** | `"What time is it?"` | Answers the current time with voice (TTS). | Verified |
| **Test 3** | `"Buka Spotify."` | Invokes `open_app(Spotify)`. | Verified |
| **Test 4** | `"Buka Safari."` | Invokes `open_app(Safari)`. | Verified |
| **Test 5** | `"Ambil screenshot."` | Screenshot captured and saved to disk. | Verified |
| **Test 6** | `"Buka Terminal dan jalankan pwd."` | Evaluates safety & asks for confirmation before executing. | Verified |
| **Test 7** | `"Buka Spotify dan cari Bruno Mars."` | Multi-step tool pipeline (`open_app` -> `type_text` -> `press_key`). | Verified |

---

## 8. Git & GitHub Branching Model

* `main` — Production-ready, stable releases.
* `development` — Integration branch for completed feature branches.
* `feat/*` — Dedicated feature branches (e.g., `feat/monorepo-foundation`, `feat/tool-system`, `feat/agent-core`, `feat/agent-server`, `feat/macos-app`, `feat/mvp-acceptance-integration`).
