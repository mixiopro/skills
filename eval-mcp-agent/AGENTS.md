# Agent Guide — Continuity MCP Workspace

Welcome! This workspace is configured as a standalone agent context designed to run evaluations on the OpenResponses Continuity API.

## Available Capabilities
1. `identity_consistency`: facial features, actor consistency.
2. `wardrobe_consistency`: outfit, accessories, color checks.
3. `lighting_consistency`: shadows, key lighting, luminosity profiles.
4. `scene_consistency`: backgrounds, set design, props.
5. `object_consistency`: consistency of specific hand props or items.
6. `prompt_consistency`: text-to-image prompts vs final visual output.

## How to use the MCP Server
Run the MCP server locally in this directory:
```bash
npx fastmcp run server.ts
```

Configure your client (e.g., Claude Desktop config) to launch the server:
```json
{
  "mcpServers": {
    "eval-mcp-agent": {
      "command": "npx",
      "args": ["fastmcp", "run", "/path/to/eval-mcp-agent/server.ts"]
    }
  }
}
```

## Skills Guidance
Refer to the `skills/` folder to guide your prompting and execution:
* `skills/prompting/SKILL.md`: Rules for structuring prompts and referencing files.
* `skills/evals-guide/SKILL.md`: Flow for preparing assets, choosing parameters, running evaluations, and analyzing reports.
