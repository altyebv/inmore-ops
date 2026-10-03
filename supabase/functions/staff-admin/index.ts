// staff-admin — the account actions that need the Auth admin API.
//
//   create          { email, password, full_name }  -> { id }
//   set_password    { user_id, password }
//   delete          { user_id }   only an account that never did anything
//
// Role, name and access are not here: the desktop app writes those to
// `employees` with the caller's own identity, so Postgres enforces the rules
// (trg_employees_restrict_role) and the history records who did it.
//
// The admin key never leaves this function. Every call is checked against the
// caller's own session: an active owner or supervisor, and a supervisor never
// acts on an owner's account.

import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const fail = (status: number, code: string, message: string) =>
  reply(status, { error: code, message });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail(405, "method", "POST only.");

  const url = Deno.env.get("SUPABASE_URL")!;
  const adminKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, adminKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Who is asking.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /i, "");
  const { data: who, error: whoErr } = await admin.auth.getUser(token);
  if (whoErr || !who?.user) return fail(401, "unauthenticated", "Sign in again.");

  const { data: caller } = await admin
    .from("employees")
    .select("id, role, is_active")
    .eq("id", who.user.id)
    .maybeSingle();
  if (!caller?.is_active || !["OWNER", "SUPERVISOR"].includes(caller.role)) {
    return fail(403, "forbidden", "Only the owner or a supervisor can manage staff.");
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail(400, "bad_request", "Expected a JSON body.");
  }

  const password = typeof body.password === "string" ? body.password : "";
  const checkPassword = () =>
    password.length < 8 ? "A password needs at least 8 characters." : null;

  // The target of set_password / delete, with the owner rule applied.
  async function target(): Promise<
    Record<string, unknown> & { id: string; role: string } | Response
  > {
    const id = typeof body.user_id === "string" ? body.user_id : "";
    if (!id) return fail(400, "bad_request", "Which account?");
    if (id === caller!.id) {
      return fail(400, "self", "You can't do that to your own account here.");
    }
    const { data } = await admin
      .from("employees")
      .select("*")
      .eq("id", id)
      .maybeSingle();
    if (!data) return fail(404, "not_found", "That account doesn't exist.");
    if (data.role === "OWNER" && caller!.role !== "OWNER") {
      return fail(403, "forbidden", "Only the owner can manage owner accounts.");
    }
    return data;
  }

  switch (body.action) {
    case "create": {
      const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
      const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
      if (!email.includes("@")) return fail(400, "email", "Enter a valid email address.");
      if (!fullName) return fail(400, "name", "Enter their name.");
      const bad = checkPassword();
      if (bad) return fail(400, "password", bad);

      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, created_by: caller.id },
      });
      if (error) {
        const taken = /already|registered|exists/i.test(error.message);
        return taken
          ? fail(409, "email_taken", "There is already an account with that email.")
          : fail(400, "auth", error.message);
      }
      // handle_new_auth_user() has made their employees row: inactive, named.
      // The app sets the role and switches it on, as the caller.
      return reply(200, { id: data.user.id });
    }

    case "set_password": {
      const t = await target();
      if (t instanceof Response) return t;
      const bad = checkPassword();
      if (bad) return fail(400, "password", bad);
      const { error } = await admin.auth.admin.updateUserById(t.id, { password });
      if (error) return fail(400, "auth", error.message);
      return reply(200, { ok: true });
    }

    case "delete": {
      const t = await target();
      if (t instanceof Response) return t;
      // employees.id is referenced, `on delete restrict`, by everything a
      // person can do or be given — requests, tasks, payments, the history.
      // If the delete goes through, they never did anything.
      const { error: rowErr } = await admin.from("employees").delete().eq("id", t.id);
      if (rowErr) {
        return rowErr.code === "23503"
          ? fail(409, "has_history",
              "This person appears in the history, so the account can only be switched off.")
          : fail(400, "db", rowErr.message);
      }
      const { error } = await admin.auth.admin.deleteUser(t.id);
      if (error) {
        // Put the profile back rather than leave a sign-in with no profile.
        await admin.from("employees").insert(t);
        return fail(400, "auth", error.message);
      }
      return reply(200, { ok: true });
    }

    default:
      return fail(400, "bad_request", "Unknown action.");
  }
});
