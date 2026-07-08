import { FastMCP } from '@prefecthq/fastmcp-ts/server';
import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const API_BASE_URL = process.env.EVAL_API_BASE_URL || 'https://eval-mastra.staging.mixio.pro';
const API_KEY = process.env.EVAL_API_KEY || '';

const mcp = new FastMCP({
  name: 'eval-mcp-agent',
  version: '1.0.0',
});

// Helper for making authenticated requests
async function callApi(endpoint: string, method: string, body?: any) {
  const url = `${API_BASE_URL}${endpoint}`;
  const response = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': API_KEY,
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`API call failed (${response.status}): ${errorText}`);
  }

  return response.json();
}

// Tool 1: Register an asset in the project library
mcp.tool(
  {
    name: 'register_asset',
    description: 'Register an uploaded asset under a project so it can be referenceable in evaluations using an @alias',
    input: z.object({
      projectId: z.string().describe('The ID of the project'),
      alias: z.string().describe('The alias to register, e.g. "char1"'),
      type: z.enum(['video', 'character', 'location', 'script', 'image', 'prop']).describe('Type of the asset'),
      sourceUrl: z.string().url().describe('Public/staged CDN URL of the media file'),
      displayName: z.string().optional().describe('Optional user-friendly name'),
      thumbnailUrl: z.string().url().optional().describe('Optional thumbnail image URL'),
      cdnUrl: z.string().url().optional().describe('Optional fallback CDN URL'),
    }),
  },
  async ({ projectId, ...body }) => {
    return callApi(`/v1/projects/${projectId}/assets`, 'POST', body);
  }
);

// Tool 2: Trigger a visual continuity evaluation run
mcp.tool(
  {
    name: 'run_evaluation',
    description: 'Submit a new visual continuity and consistency evaluation job',
    input: z.object({
      evaluation_capability: z.enum([
        'wardrobe_consistency',
        'identity_consistency',
        'lighting_consistency',
        'scene_consistency',
        'object_consistency',
        'prompt_consistency'
      ]).describe('The evaluation capability to check'),
      prompt: z.string().describe('Instructions outlining what to evaluate, e.g. "Verify the visual flow of @video"'),
      image_urls: z.array(z.string().url()).optional().describe('List of public URLs if checking keyframe images directly'),
      video_url: z.string().url().optional().describe('The public URL of the video file if evaluating a video'),
      algorithm: z.string().optional().default('gemini_review').describe('Algorithm to run (defaults to "gemini_review")'),
      threshold: z.number().optional().default(0.80).describe('Evaluation confidence/similarity threshold (0.0 to 1.0)'),
      background: z.boolean().optional().default(true).describe('Whether to run asynchronously in the background'),
    }),
  },
  async (payload) => {
    return callApi('/v1/responses', 'POST', payload);
  }
);

// Tool 3: Get background evaluation status and results
mcp.tool(
  {
    name: 'get_evaluation_result',
    description: 'Poll or retrieve the status and results of a submitted background evaluation task',
    input: z.object({
      responseId: z.string().describe('The response job ID returned from a background evaluation run (starting with "resp_")'),
    }),
  },
  async ({ responseId }) => {
    return callApi(`/v1/responses/${responseId}`, 'GET');
  }
);

// Tool 4: List all available projects
mcp.tool(
  {
    name: 'list_projects',
    description: 'List all production review projects in the database',
    input: z.object({}),
  },
  async () => {
    return callApi('/v1/projects', 'GET');
  }
);

await mcp.run();
