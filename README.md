# CivicSense

A social network for everyday good — people upload the good things they did today.

## Pages

| File | Description |
|------|-------------|
| `index.html` | Landing page |
| `signup.html` | Individual sign up → redirects to login |
| `business-signup.html` | Business / nonprofit sign up → redirects to profile |
| `login.html` | Log in → redirects to social feed |
| `social.html` | Live social feed (post, load, realtime) |
| `business-profile.html` | Edit profile (auth required) |
| `supabase-schema.sql` | Full database schema |

## Supabase (already wired)

Credentials are already set in all pages:

```
URL:  https://upmlijvwbzctaglsrcfu.supabase.co
```

### One-time setup in Supabase Dashboard

1. **SQL Editor** → paste and run `supabase-schema.sql` (creates profiles, businesses, posts, storage, RLS, triggers).

2. **Authentication → Providers** → Email enabled (default).

3. **Authentication → URL Configuration** → add your site URL if needed.

4. **Database → Replication** (optional, for live feed): enable `posts` table for Realtime.

5. **Storage** → confirm `avatars` bucket is public (created by the SQL).

## Working features

- **Sign up** (individual + business) with Supabase Auth + profile auto-create trigger
- **Login** / password reset
- **Social feed**: create posts, load posts with author profiles, optimistic UI, realtime inserts
- **Edit profile**: load/save profile + business fields, avatar upload to Storage
- Auth guards: profile page redirects to login if not signed in; posting requires login

## Local use

Open any HTML file in a browser, or serve the folder:

```bash
npx serve .
```

All paths are relative (`login.html`, `social.html`, etc.).
