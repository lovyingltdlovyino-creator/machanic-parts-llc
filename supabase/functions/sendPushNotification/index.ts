// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ChatPushRequest = {
  type: "chat_message";
  message_id: string;
  conversation_id?: string;
  content?: string;
};

type AdminBroadcastRequest = {
  type: "admin_broadcast";
  title: string;
  body: string;
  audience: "seller" | "buyer" | "both";
};

type PushRequest = ChatPushRequest | AdminBroadcastRequest;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const FIREBASE_PRIVATE_KEY = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");

const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function truncate(value: string, max = 160) {
  return value.length > max ? `${value.slice(0, max - 3)}...` : value;
}

async function getAuthenticatedUser(authHeader: string | null) {
  if (!authHeader) {
    return { user: null, client: null };
  }

  const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    return { user: null, client };
  }

  return { user: data.user, client };
}

async function getAccessToken() {
  if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
    console.warn("[Push] Firebase service-account credentials are missing.");
    return null;
  }

  const jwtClient = new JWT({
    email: FIREBASE_CLIENT_EMAIL,
    key: FIREBASE_PRIVATE_KEY,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const tokens = await jwtClient.authorize();
  return tokens.access_token ?? null;
}

async function revokeInvalidToken(token: string) {
  await serviceClient
    .from("push_tokens")
    .update({ revoked_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("token", token);
}

async function sendFcmMessage(accessToken: string, token: string, payload: Record<string, any>) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: Object.fromEntries(
            Object.entries(payload.data ?? {}).map(([key, value]) => [key, String(value)])
          ),
          android: {
            priority: "high",
            notification: {
              channel_id: payload.channelId ?? "chat_messages",
            },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        },
      }),
    },
  );

  if (response.ok) return { ok: true };

  const errorText = await response.text();
  if (errorText.includes("UNREGISTERED") || errorText.includes("registration-token-not-registered")) {
    await revokeInvalidToken(token);
  }

  return { ok: false, errorText };
}

async function sendToUsers(userIds: string[], payload: Record<string, any>, sentBy: string | null) {
  if (userIds.length === 0) {
    return { recipients: 0, tokenCount: 0, pushed: 0, failed: 0, reason: "no_recipients" };
  }

  const notificationRows = userIds.map((userId) => ({
    user_id: userId,
    kind: payload.data?.type ?? "general",
    title: payload.title,
    body: payload.body,
    data: payload.data ?? {},
    sent_by: sentBy,
  }));

  await serviceClient.from("user_notifications").insert(notificationRows);

  const { data: tokens } = await serviceClient
    .from("push_tokens")
    .select("token, user_id")
    .in("user_id", userIds)
    .is("revoked_at", null);

  const uniqueTokens = Array.from(
    new Map((tokens ?? []).map((pushToken) => [pushToken.token, pushToken])).values(),
  );

  if (!uniqueTokens.length) {
    console.warn(`[Push] No active push tokens found for users: ${userIds.join(", ")}`);
    return {
      recipients: userIds.length,
      tokenCount: 0,
      pushed: 0,
      failed: 0,
      reason: "no_push_tokens",
    };
  }

  const accessToken = await getAccessToken();
  if (!accessToken) {
    return {
      recipients: userIds.length,
      tokenCount: uniqueTokens.length,
      pushed: 0,
      failed: uniqueTokens.length,
      reason: "missing_firebase_credentials",
    };
  }

  let pushed = 0;
  const sampleErrors: string[] = [];

  for (const pushToken of uniqueTokens) {
    const result = await sendFcmMessage(accessToken, pushToken.token, payload);
    if (result.ok) {
      pushed += 1;
      continue;
    }

    if (sampleErrors.length < 3) {
      sampleErrors.push(result.errorText);
    }
  }

  return {
    recipients: userIds.length,
    tokenCount: uniqueTokens.length,
    pushed,
    failed: uniqueTokens.length - pushed,
    reason: pushed == uniqueTokens.length
      ? "sent"
      : pushed > 0
      ? "partial_failure"
      : "send_failed",
    sampleErrors,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { user } = await getAuthenticatedUser(req.headers.get("Authorization"));
    if (!user) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }

    const body = (await req.json()) as PushRequest;

    if (body.type === "chat_message") {
      let message:
        | {
            id: string;
            conversation_id: string;
            sender_id: string;
            content: string;
          }
        | null = null;

      if (body.message_id) {
        const { data } = await serviceClient
          .from("messages")
          .select("id, conversation_id, sender_id, content")
          .eq("id", body.message_id)
          .maybeSingle();
        if (data) {
          message = {
            id: data.id,
            conversation_id: data.conversation_id,
            sender_id: data.sender_id,
            content: data.content ?? body.content ?? "",
          };
        }
      }

      const conversationId = message?.conversation_id ?? body.conversation_id;
      if (!conversationId) {
        return new Response(JSON.stringify({ error: "Conversation not found" }), {
          status: 404,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      const { data: conversation, error: conversationError } = await serviceClient
        .from("conversations")
        .select("id, buyer_id, seller_id, listing_id")
        .eq("id", conversationId)
        .maybeSingle();

      if (conversationError || !conversation) {
        return new Response(JSON.stringify({ error: "Conversation not found" }), {
          status: 404,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      if (!conversation || (conversation.buyer_id !== user.id && conversation.seller_id !== user.id)) {
        return new Response(JSON.stringify({ error: "Forbidden" }), {
          status: 403,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      const recipientId = conversation.buyer_id === user.id ? conversation.seller_id : conversation.buyer_id;

      const { data: senderProfile } = await serviceClient
        .from("profiles")
        .select("business_name, contact_person")
        .eq("id", user.id)
        .maybeSingle();

      const senderName =
        senderProfile?.business_name?.trim() ||
        senderProfile?.contact_person?.trim() ||
        user.email ||
        "Mechanic Part user";

      const payload = {
        title: `New message from ${senderName}`,
        body: truncate(message?.content ?? body.content ?? "You have a new message."),
        channelId: "chat_messages",
        data: {
          type: "chat_message",
          conversation_id: conversation.id,
          listing_id: conversation.listing_id,
          message_id: message?.id ?? body.message_id,
        },
      };

      const result = await sendToUsers([recipientId], payload, user.id);
      return new Response(JSON.stringify(result), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const { data: adminProfile } = await serviceClient
      .from("profiles")
      .select("is_admin")
      .eq("id", user.id)
      .maybeSingle();

    if (!adminProfile?.is_admin) {
      return new Response(JSON.stringify({ error: "Admins only" }), {
        status: 403,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    let profileQuery = serviceClient
      .from("profiles")
      .select("id")
      .or("admin_blocked.is.null,admin_blocked.eq.false");

    if (body.audience !== "both") {
      profileQuery = profileQuery.eq("user_type", body.audience);
    }

    const { data: profiles, error: profilesError } = await profileQuery;
    if (profilesError) {
      throw profilesError;
    }

    const userIds = (profiles ?? []).map((profile) => profile.id as string);
    const payload = {
      title: truncate(body.title, 120),
      body: truncate(body.body, 200),
      channelId: "admin_broadcasts",
      data: {
        type: "admin_broadcast",
        audience: body.audience,
      },
    };

    const result = await sendToUsers(userIds, payload, user.id);
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
