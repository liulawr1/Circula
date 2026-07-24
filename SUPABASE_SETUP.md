# Circula Supabase Setup

The app now uses Supabase/Postgres through Supabase's REST API. No Apple Developer Program or CloudKit container is required.

## What you need to do

1. Create a Supabase project at `https://supabase.com`.
2. Open the project, then go to **SQL Editor**.
3. Paste and run the contents of `SUPABASE_SCHEMA.sql`.
4. Go to **Project Settings > API**.
5. Copy:
   - **Project URL**
   - **anon public** key
6. Open `Circula/SupabaseConfig.plist`.
7. Replace:

```text
YOUR_SUPABASE_PROJECT_URL
YOUR_SUPABASE_ANON_KEY
```

with your real values.

When those values are still placeholders, Circula cannot load or change shared marketplace data.

## Add authentication

If you already ran the schema before authentication was added, run `SUPABASE_AUTH_UPDATE.sql` in **SQL Editor** too. It creates:

- `public.profiles`, linked to `auth.users`
- a signup trigger that rejects non-`@headroyce.org` emails
- a `delete_current_user()` RPC function used by the in-app Delete Account button
- row-level security policies for profile records

Then go to **Authentication > Providers > Email** and keep **Confirm email** turned on. That is what prevents fake `@headroyce.org` addresses from logging in: the user has to receive the Supabase confirmation email before they can sign in.

Also go to **Authentication > URL Configuration**:

1. Set **Site URL** to:

```text
circula://email-verified
```

2. Add the same URL to **Redirect URLs** if Supabase shows that list:

```text
circula://email-verified
```

Do not leave the Site URL as `http://localhost:3000`, and do not use the raw Supabase project URL as the final redirect. The raw Supabase project domain verifies the email correctly, but it does not host an app page, so it can show `{"error":"requested path is invalid"}` after verification.

The app registers the `circula://` URL scheme. When a student opens the newest verification email on a device with Circula installed, the link opens the app and shows an email-verified message. Then the student can sign in.

## Required production security

Before uploading a build to App Store Connect, open **SQL Editor**, paste the full contents of `SUPABASE_PRODUCTION_SECURITY.sql`, and run it.

This migration preserves existing data and:

- lets guests read public listing details without receiving owner email addresses
- lets signed-in students change only their own listings and saved items
- limits conversations and messages to their participants
- keeps reports private to the moderator account
- allows both guests and signed-in students to submit safety reports

Do not rerun `SUPABASE_SCHEMA.sql` on the live project. It resets the app tables. For an existing project, run only the authentication update if still needed, followed by `SUPABASE_PRODUCTION_SECURITY.sql`.
