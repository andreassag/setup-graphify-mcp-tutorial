# Running Graphify MCP via Docker Compose: Quick Setup Guide

A lightweight, centralized setup to run **Graphify** (`graphifyy`) as a containerized Model Context Protocol (MCP) server for AI coding assistants without cluttering host Python dependencies.

---

## Directory Layout

Store the Docker setup in a workspace-specific location (e.g., `.mcp/graphify` in your project root) or a centralized location on your system:

### macOS / Linux

- **Centralized location**: `~/.mcp/graphify/`
- **Workspace-specific location**: `path/to/project/.mcp/graphify/`

```text
~/.mcp/graphify/
├── Dockerfile          # Required only when building locally
├── docker-compose.yml  # Service definitions
└── .env                # Local environment configuration (optional)
```

### Windows 11

- **Centralized location**: `%USERPROFILE%\.mcp\graphify\` (e.g., `C:\Users\<username>\.mcp\graphify\`)
- **Workspace-specific location**: `C:\path\to\project\.mcp\graphify\`

```text
C:\Users\<username>\.mcp\graphify\
├── Dockerfile          # Required only when building locally
├── docker-compose.yml  # Service definitions
└── .env                # Local environment configuration (optional)
```

> **Note**: If you are using pre-built images from Docker Hub or GitHub Container Registry, only `docker-compose.yml` (and `.env` if using API keys) is required.

---

## 1. Installation & Image Setup

Choose one of the two approaches depending on whether you want to build the container locally from the `Dockerfile` or pull a pre-built image from a registry.

### Option A: Building from Dockerfile (Local Build)

Use this method if you want to build or modify the container image locally.

1. Create or place `Dockerfile`:

```dockerfile
ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim

ARG GRAPHIFYY_VERSION=0.9.80

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install graphify with MCP dependencies
RUN pip install --no-cache-dir "graphifyy[mcp]==${GRAPHIFYY_VERSION}"

WORKDIR /workspace

# Default command starts the MCP server on the generated graph
ENTRYPOINT ["python", "-m", "graphify.serve"]
CMD ["graphify-out/graph.json"]
```

2. Build the image locally:

- **Using Docker CLI**:
  - **macOS / Linux**:
    ```bash
    docker build -t graphify:latest ~/.mcp/graphify
    ```
  - **Windows 11**:
    ```powershell
    docker build -t graphify:latest "$HOME\.mcp\graphify"
    ```

- **Using Docker Bake (`docker-bake.hcl`)**:
  ```bash
  docker buildx bake
  ```

*(Note: When using a locally built image, ensure `image: graphify:latest` in `docker-compose.yml` matches your local tag).*

### Option B: Pulling Pre-built Image from Registry

Use this method if you want to use pre-built images without maintaining a local `Dockerfile`.

Pre-built images are published to Docker Hub and GitHub Container Registry (GHCR):
- **Docker Hub**: `andreassag/graphify:latest` (or tagged versions like `andreassag/graphify:0.9.8`)
- **GitHub Container Registry (GHCR)** *(upcoming)*: `ghcr.io/andreassag/graphify:latest`

Pull the image:

```bash
# Pull from Docker Hub
docker pull andreassag/graphify:latest

# Pull from GitHub Container Registry (upcoming)
docker pull ghcr.io/andreassag/graphify:latest
```

When pulling from a registry, you only need `docker-compose.yml` and your `.env` configuration.

---

## 2. Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
services:
  graphify-build:
    image: andreassag/graphify:latest
    profiles: ["cli", "build"]
    user: "${UID:-1000}:${GID:-1000}"
    volumes:
      - ./:/workspace
    working_dir: /workspace
    environment:
      - GEMINI_API_KEY=${GEMINI_API_KEY:-}
    entrypoint: ["graphify"]
    command: ["."] # Use [".", "--code-only"] to only analyze code files, i.e. without a GEMINI_API_KEY

  graphify-mcp:
    image: andreassag/graphify:latest
    profiles: ["mcp"]
    user: "${UID:-1000}:${GID:-1000}"
    stdin_open: true
    volumes:
      - ./:/workspace
    working_dir: /workspace
    command: ["graphify-out/graph.json"]

  graphify-ui:
    image: python:3.14-slim
    profiles: ["ui"]
    ports:
      - "8080:8080"
    volumes:
      - ./graphify-out:/data:ro
    command: ["python", "-m", "http.server", "8080", "-d", "/data"]
```

### Environment Configuration (`.env`)

Docker Compose automatically loads variables from a `.env` file located in the same directory as `docker-compose.yml`.

Create a `.env` file in the same directory as `docker-compose.yml` (e.g., `~/.mcp/graphify/.env` or `C:\Users\<username>\.mcp\graphify\.env`):

```bash
# GEMINI_API_KEY is required for LLM enrichment on Markdown/PDFs.
# Can be left blank if running with --code-only (local AST analysis only).
GEMINI_API_KEY=your_gemini_api_key_here

# User and group IDs for file permissions in Docker (defaults to 1000:1000)
UID=1000
GID=1000
```

> **Note on `--code-only`**: Local AST parsing requires no API keys. If you want LLM enrichment on Markdown/PDFs, remove `--code-only` from the `graphify-build` command and supply an API key (e.g., `GEMINI_API_KEY` or any other compatible graphify environment variable, see [Graphify docs](https://github.com/Graphify-Labs/graphify#environment-variables)) via `.env`.

---

## 3. Indexing a Target Project

Run the indexer from the root of any repository you want to analyze:

### macOS / Linux

```bash
cd /path/to/my-project
docker compose --project-directory . -f ~/.mcp/graphify/docker-compose.yml run --rm graphify-build
```

### Windows 11

```powershell
cd C:\path\to\my-project
docker compose --project-directory . -f "$HOME\.mcp\graphify\docker-compose.yml" run --rm graphify-build
```

This generates `graphify-out/graph.json`, `graphify-out/graph.html`, and `graphify-out/GRAPH_REPORT.md` in the target project root.

---

## 4. MCP Client Configuration

### Base Configuration (`mcp.json`)

Most MCP-compatible clients use an `mcpServers` object in their configuration file. Below is the base definition:

```json
{
    "mcpServers": {
        "graphify": {
            "command": "docker",
            "args": [
                "compose",
                "--project-directory",
                ".",
                "-f",
                "/home/<user>/.mcp/graphify/docker-compose.yml",
                "run",
                "--rm",
                "-i",
                "-T",
                "graphify-mcp"
            ]
        }
    }
}
```

> **Path Note**: Replace `/home/<user>/` with your actual absolute home path (e.g., `/Users/<username>/` on macOS, `/home/<username>/` on Linux) as MCP clients do not expand `~`.
>
> **Windows 11 Note**: On Windows 11, replace the compose file path with `C:/Users/<username>/.mcp/graphify/docker-compose.yml` (using forward slashes or escaped backslashes `\\`).

---

### Client Configuration Locations

Instead of repeating the JSON block for each tool, add the base `graphify` entry to the corresponding client configuration file or use the CLI command:

| Client | Scope / Platform | Configuration Path / CLI Command |
| :--- | :--- | :--- |
| **Google Antigravity** | Global | `~/.gemini/config/mcp_config.json` |
| | Workspace | `.agents/mcp_config.json` (repository root) |
| **Claude Desktop** | macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| | Windows 11 | `%APPDATA%\Claude\claude_desktop_config.json` |
| **Claude Code** | CLI | `claude mcp add graphify -- docker compose --project-directory . -f /home/<user>/.mcp/graphify/docker-compose.yml run --rm -i -T graphify-mcp` |
| **OpenAI Codex** | Global | `~/.codex/config.json` |
| | Workspace | `.codex/config.json` (repository root) |
| | CLI | `codex mcp add graphify -- docker compose --project-directory . -f /home/<user>/.mcp/graphify/docker-compose.yml run --rm -i -T graphify-mcp` |

> **Tip**: In **Antigravity**, you can verify active MCP tools (`query_graph`, `get_node`, `shortest_path`) under **Additional Options (...) > MCP Servers**.

---

## 5. Verification & Testing

### Test Stdio JSON-RPC Handshake Directly

Run this from the project root containing `graphify-out/`:

#### macOS / Linux

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | docker compose --project-directory . -f ~/.mcp/graphify/docker-compose.yml run --rm -i -T graphify-mcp
```

#### Windows 11

```powershell
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | docker compose --project-directory . -f "$HOME\.mcp\graphify\docker-compose.yml" run --rm -i -T graphify-mcp
```

Expected output:

```json
{"jsonrpc":"2.0","id":1,"result":{"capabilities":{"tools":{"listChanged":false}},"protocolVersion":"2024-11-05","serverInfo":{"name":"graphify","version":"0.9.80"}}}
```

### Test in MCP Inspector

Launch the browser-based inspector:

```bash
npx @modelcontextprotocol/inspector docker compose --project-directory . -f ~/.mcp/graphify/docker-compose.yml run --rm -i -T graphify-mcp
```

Click the toggle switch on the docker server card to connect and inspect tools (`query_graph`, `get_node`, `shortest_path`).
