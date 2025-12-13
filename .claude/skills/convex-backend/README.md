# Convex Backend Platform Skill

**Full-stack TypeScript backend with reactive database and real-time synchronization**

## Quick Start

```bash
# Install Convex
pnpm add convex

# Initialize project
pnpm dlx convex dev --configure

# Start development
pnpm dlx convex dev
```

## What This Skill Covers

### Core Capabilities
- **Reactive Database** - Automatic real-time updates across all clients
- **Server Functions** - Queries (read), Mutations (write), Actions (external)
- **Authentication** - Built-in support for Clerk, Auth0, custom JWT, database auth
- **File Storage** - CDN-backed storage with automatic URL generation
- **Scheduled Functions** - Cron jobs for background tasks
- **TypeScript Safety** - End-to-end type safety from schema to client

### Common Operations
- CRUD operations with TypeScript type safety
- Real-time query subscriptions
- User authentication and authorization
- File uploads and downloads
- Background job scheduling
- Database indexes and pagination

### When to Use Convex
✅ **Perfect For:**
- Real-time collaborative apps (chat, docs, whiteboards)
- AI-powered applications with RAG and streaming
- Task management and productivity tools
- E-commerce with live inventory
- Rapid MVP development
- TypeScript-first teams

❌ **Consider Alternatives If:**
- You need direct SQL access
- You require complete vendor independence
- You have existing PostgreSQL expertise
- You need traditional relational database features

## Example: Real-Time Chat

```typescript
// convex/messages.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Query - automatically updates when new messages arrive
export const list = query({
  handler: async (ctx) => {
    return await ctx.db.query("messages").order("desc").take(100);
  },
});

// Mutation - send a new message
export const send = mutation({
  args: { text: v.string(), author: v.string() },
  handler: async (ctx, args) => {
    await ctx.db.insert("messages", {
      text: args.text,
      author: args.author,
      timestamp: Date.now(),
    });
  },
});
```

```typescript
// React client - automatically updates in real-time
import { useQuery, useMutation } from "convex/react";
import { api } from "../convex/_generated/api";

export function Chat() {
  const messages = useQuery(api.messages.list); // Real-time!
  const sendMessage = useMutation(api.messages.send);

  return (
    <div>
      {messages?.map(msg => <div key={msg._id}>{msg.text}</div>)}
      <button onClick={() => sendMessage({ text: "Hi!", author: "User" })}>
        Send
      </button>
    </div>
  );
}
```

## Key Features

### 1. Zero WebSocket Configuration
No need to set up WebSockets, Redis, or Socket.io. Convex handles all real-time coordination automatically.

### 2. Optimistic Updates
Built-in support for optimistic UI updates with automatic rollback on errors.

### 3. Developer Experience
- Local development with instant hot reloading
- TypeScript type generation from schemas
- React hooks for queries and mutations
- Built-in dashboard for data inspection

### 4. Performance
- Automatic query result caching
- Efficient delta updates (only changed data)
- Connection reuse and batching
- Edge caching for static data

## CLI Commands

```bash
# Development
pnpm dlx convex dev              # Start dev server with dashboard
pnpm dlx convex dev --once       # Run sync once and exit

# Deployment
pnpm dlx convex deploy           # Deploy to production
pnpm dlx convex deploy --cmd "npm run build"  # Build then deploy

# Environment Management
pnpm dlx convex env set KEY value          # Set environment variable
pnpm dlx convex env list                   # List all variables
pnpm dlx convex env remove KEY             # Remove variable

# Data Management
pnpm dlx convex data import --table users data.json  # Import data
pnpm dlx convex data export --table users            # Export data
```

## Architecture

```
┌─────────────────────────────────────────────┐
│          Client Applications                │
│  (React, Next.js, Vue, Svelte, Mobile)     │
└──────────────┬──────────────────────────────┘
               │ WebSocket (real-time)
               ▼
┌─────────────────────────────────────────────┐
│         Convex Backend Platform             │
│  ┌────────────────────────────────────────┐ │
│  │  Queries (Read)    Mutations (Write)   │ │
│  │  Actions (External)  Scheduled         │ │
│  └────────────┬───────────────────────────┘ │
│               ▼                              │
│  ┌────────────────────────────────────────┐ │
│  │      Reactive Database                 │ │
│  │  (Automatic dependency tracking)       │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │     File Storage + CDN                 │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Best Practices

### 1. Schema Design
- Use TypeScript types for schema definition
- Define indexes for frequently queried fields
- Use relationships via document IDs

### 2. Query Optimization
- Use indexes instead of `.filter()` after `.collect()`
- Implement pagination for large result sets
- Avoid nested queries (use joins via `.get()`)

### 3. Function Design
- Keep queries deterministic (no random, Date.now, external calls)
- Use mutations for database writes
- Use actions for third-party API calls
- Schedule long-running tasks with cron

### 4. Authentication
- Store user data in a separate `users` table
- Use `ctx.auth.getUserIdentity()` for identity
- Implement row-level security in queries/mutations

### 5. Error Handling
- Throw errors in mutations to trigger automatic rollback
- Use try-catch for graceful degradation
- Return error states from actions

## Pricing

**Free Tier:**
- 1 GB database bandwidth/month
- 1 GB file storage
- 1 GB file bandwidth/month
- Unlimited queries, mutations, actions
- Personal dev deployments

**Paid Plans:**
- Scales to billions of documents
- No hard limits on bandwidth
- Production team features
- Priority support

## Resources

- **Official Docs:** https://docs.convex.dev
- **GitHub:** https://github.com/get-convex
- **Components:** https://convex.dev/components (RAG, Auth, Email, etc.)
- **Community:** Discord, Stack Overflow
- **Research Report:** `CONVEX-PLATFORM-RESEARCH-REPORT.md`

## Integration Examples

### Next.js App Router
```typescript
// app/ConvexClientProvider.tsx
"use client";
import { ConvexProvider, ConvexReactClient } from "convex/react";

const convex = new ConvexReactClient(process.env.NEXT_PUBLIC_CONVEX_URL!);

export function ConvexClientProvider({ children }: { children: React.ReactNode }) {
  return <ConvexProvider client={convex}>{children}</ConvexProvider>;
}
```

### Authentication with Clerk
```typescript
// convex/auth.ts
import { Auth } from "convex/server";

export async function getUserId(ctx: { auth: Auth }) {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) throw new Error("Not authenticated");

  const user = await ctx.db
    .query("users")
    .withIndex("by_token", q => q.eq("tokenIdentifier", identity.tokenIdentifier))
    .unique();

  if (!user) throw new Error("User not found");
  return user._id;
}
```

### File Upload
```typescript
// Generate upload URL (mutation)
export const generateUploadUrl = mutation(async (ctx) => {
  return await ctx.storage.generateUploadUrl();
});

// Store file ID (mutation)
export const saveStorageId = mutation({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, args) => {
    await ctx.db.insert("images", { storageId: args.storageId });
  },
});

// Get file URL (query)
export const getImageUrl = query({
  args: { imageId: v.id("images") },
  handler: async (ctx, args) => {
    const image = await ctx.db.get(args.imageId);
    if (!image) return null;
    return await ctx.storage.getUrl(image.storageId);
  },
});
```

## Troubleshooting

### Common Issues

**"Cannot find module" errors:**
```bash
# Regenerate types
pnpm dlx convex dev --once
```

**Queries not updating in real-time:**
- Ensure you're using `useQuery` (not `useQuery` from React Query)
- Check WebSocket connection in browser dev tools
- Verify database changes are in the same table being queried

**Performance issues:**
- Add indexes for frequently queried fields
- Use pagination instead of loading all data
- Profile queries in Convex dashboard

**Authentication not working:**
- Verify JWT configuration matches provider
- Check `tokenIdentifier` is correctly stored
- Ensure `getUserIdentity()` is called in auth context

## Next Steps

1. Read the full skill documentation: `skill.md`
2. Review the research report: `CONVEX-PLATFORM-RESEARCH-REPORT.md`
3. Explore official examples: https://github.com/get-convex/templates
4. Join the community: https://discord.gg/convex

---

**Skill Location:** `.claude/skills/convex-backend/`
**Last Updated:** 2025-12-09
**Maintained By:** Claude Code Agent Swarm
