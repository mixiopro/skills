# Continuity MCP Agent

A Model Context Protocol (MCP) server that exposes tools to orchestrate and poll visual continuity evaluations on the OpenResponses server.

---

## Setup Instructions

1. **Install Dependencies:**
   Navigate to this directory and install node modules:
   ```bash
   cd eval-mcp-agent
   npm install
   ```

2. **Configure Environment Variables:**
   Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
   Each user must supply their own evaluation API token. Modify `.env` to configure your keys:
   * `EVAL_API_BASE_URL`: Base URL of the running Hono API Orchestrator (defaults to the staging endpoint `https://eval-mastra.staging.mixio.pro`).
   * `EVAL_API_KEY`: Your personal staging evaluation API token (do not commit your active `.env` file).

---

## Running the MCP Server

Start the server using `tsx` or the fastmcp CLI:
```bash
# Run in development mode (with hot reloading)
npm run dev

# Or start directly
npm start
```

---

## Integrating with Claude Desktop

To connect Claude Desktop to this server, add the following configuration block to your Claude Desktop config (usually located at `~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

```json
{
  "mcpServers": {
    "eval-mcp-agent": {
      "command": "npx",
      "args": [
        "-y",
        "tsx",
        "/absolute/path/to/eval-mcp-agent/server.ts"
      ],
      "env": {
        "EVAL_API_BASE_URL": "https://eval-mastra.staging.mixio.pro",
        "EVAL_API_KEY": "your-eval-api-token-here"
      }
    }
  }
}
```

Replace `/absolute/path/to/eval-mcp-agent/` with the actual path to this folder on your disk.
