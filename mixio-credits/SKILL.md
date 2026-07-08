---
name: mixio-credits
description: "Track and manage Mixio Studio credits — check balance, view usage history, understand pricing, and top up."
version: 0.1.0
invoke: /mixio:credits
---

# Mixio Credits

Monitor and manage your Mixio Studio credit balance and usage.

## Prerequisites

- Mixio CLI installed and configured: `npm install -g mixiocode && mixio setup`
- Or: API key set in MCP server environment

## MCP Tools

### `credits_balance`

Get current credit balance and plan info.

```json
{
  "tool": "credits_balance",
  "arguments": {}
}
```

Returns:
```json
{
  "balance": 450,
  "plan": "pro",
  "refill_date": "2026-08-01",
  "monthly_allocation": 1000,
  "used_this_period": 550
}
```

### `usage_history`

Get recent generation usage with credit costs.

```json
{
  "tool": "usage_history",
  "arguments": {
    "limit": 20,
    "since": "2026-07-01"
  }
}
```

Returns array of:
```json
{
  "job_id": "gen_abc123",
  "model": "fal/flux-pro",
  "credits_used": 3,
  "timestamp": "2026-07-07T10:30:00Z",
  "status": "completed",
  "prompt_preview": "A cinematic wide..."
}
```

## Pricing

### Image Generation
| Model | Credits per image |
|-------|------------------|
| Fal FLUX Pro | 3 |
| Fal Recraft v3 | 2 |
| Gemini Imagen 4 | 3 |
| GPT Image | 4 |

### Video Generation
| Model | Credits per second |
|-------|-------------------|
| Sora | 3 |
| BytePlus | 1 |
| Fal Kling | 2 |
| Fal Minimax | 2 |

### Audio
| Model | Credits per minute |
|-------|-------------------|
| ElevenLabs TTS | 2 |
| ElevenLabs SFX | 1 |

### Storage
- Uploads: free (included in plan)
- CDN bandwidth: free up to 100GB/month

## Top Up

Credits can be purchased via the Studio dashboard or Razorpay checkout:
- 500 credits: ₹499
- 1000 credits: ₹899
- 5000 credits: ₹3,999

## Tips

- Use `credits_balance` before large batch jobs to ensure sufficient credits
- Video generation is the most expensive — use BytePlus for drafts, Sora for finals
- Failed generations are not charged
- Credits roll over month-to-month on paid plans
