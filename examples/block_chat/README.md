# Block Chat — Android neighbourhood messenger

This is a **standalone, Android-only Flutter app**, using the same Flutter, Material 3, testing, and release-workflow patterns that powered the existing cooking and business app projects. It is not a screen embedded in Recipe Haven or any of the other products. Source is isolated under examples/block_chat, and its package identity is com.cruefan94.block_chat.

## Current functionality in source

- Email/password account signup and sign-in with email verification support.
- Each private Block is created by a founder, with independent membership.
- 160-bit one-time invitations issued by Block admins, expiring after 48 hours.
- Code redemption places a member into **pending** status, not directly into chat.
- Admins accept or reject join requests, remove members, issue codes and review message reports.
- Each approved member sees only their joined Blocks.
- Live text chat in General, Announcements, Neighbour Help, and Events channels.
- Posting to Announcements is restricted to admins.
- Users can report inappropriate messages; admins can redact messages.
- PostgreSQL Row Level Security and privileged server-side RPCs enforce permissions.

## Not yet verified or implemented

- **No production backend configured or deployed from this repository.**
- No end-to-end encryption. Supabase's HTTPS/TLS transport and managed storage
  are not equivalent to E2EE. Do not advertise "encrypted private chat" without an
  independently reviewed E2EE implementation and key-management strategy.
- No physical Android device or live two-account test yet.
- No phone push notifications, voice, media attachments, user-level blocking,
  anti-harassment escalation or account deletion process yet.
- Invites plus administrator approval are NOT proof of a person's address.
- The name "Block Chat" is temporary pending final trademark/brand clearance.

## Required secure backend setup

1. Create an independent Supabase project (not one containing Recipe Haven data).
2. In the SQL Editor, apply
   supabase/migrations/0001_private_blocks.sql on the new project.
3. Enable Email authentication. Require email confirmation; set sensible
   authentication and email rate limits. Configure sender/email delivery.
4. Under GitHub repository **Settings > Secrets and variables > Actions**,
   create BLOCK_CHAT_SUPABASE_URL and BLOCK_CHAT_SUPABASE_PUBLISHABLE_KEY.
   These are a URL and a PUBLIC client key, never a secret or service_role key.
5. Review the migration and verify access-control behavior with two accounts:
   invited member cannot read before approval; joins are per Block; unauthorized
   cross-Block reads, posts, and invitation creation must fail; moderators can
   only act inside their own Blocks.
6. Only after verification, trigger the dedicated Block Chat Android workflow.
   It builds and uploads an independently named test APK with the configured project.

The GitHub source CI can analyze Flutter, run unit tests, and compile Android
platform code without backend credentials. It must **NOT publish a nonfunctional
chat APK** without a configured, verified backend.

## Security and release boundaries

- All RLS-sensitive operations happen in PostgreSQL functions and policies,
  not merely via hidden UI.
- The SQL migration is source-only until someone explicitly applies it
  to their independent Supabase project.
- Invite secrets are only returned once; only SHA-256 hashes are retained.
- Messages are readable to authorized members and backend administrators;
  they are NOT end-to-end encrypted.
- If a member is removed, previously viewed or copied messages cannot be
  retrieved from the user's device by revoking database permissions.
- Supabase Email Auth stores account information under provider policies.
  Production requires privacy policy, user-data export/deletion, moderation
  procedures, abuse controls and independent penetration/security review.
- Test installer signing is **not a stable upgrade identity** until a dedicated
  permanent Android keystore is configured. Do not use Recipe Haven signing keys.
- No iOS work, no Copilot, and no source changes to the four existing apps.

## Android source validation

From examples/block_chat:

    flutter pub get
    flutter analyze
    flutter test

Build once configured:

    bash scripts/bootstrap_block_chat_android.sh
    cd examples/block_chat
    flutter build apk --release \
      --dart-define="BLOCK_CHAT_SUPABASE_URL=https://YOUR_PROJECT.supabase.co" \
      --dart-define="BLOCK_CHAT_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY"

Keep credentials out of copied shell histories when possible; use Actions
secrets for CI builds.

This source is a **development integration checkpoint**, not a finished, verified secure communication product.
