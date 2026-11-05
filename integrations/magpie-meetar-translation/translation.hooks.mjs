import { randomUUID } from "node:crypto";
import { paths } from "./paths.mjs";
import { injectPolicy, loadPolicy } from "./policy.mjs";
import { recordRequest, recordResponse } from "./records.mjs";

const MODEL = "group/translate";

/** Only the owner's local translation requests opt into capture and enrichment. */
export async function onRequest(body, ctx) {
  if (body?.model !== MODEL || ctx.model !== MODEL || !["local", "magpie-key"].includes(ctx.origin)) return;
  // The official app shares this group on this Mac but must retain its behavior.
  if (ctx.agent === "Easydict") return;
  if (ctx.protocol !== "chat") {
    report(ctx, "unsupported_protocol");
    return;
  }

  let files;
  let policy;
  let effectiveRequest;
  try {
    files = paths(ctx.options);
    policy = loadPolicy(files.policy);
    effectiveRequest = injectPolicy(body, policy);
  } catch {
    report(ctx, "policy_error");
    // Throw so Magpie reports a failed hook and retains the caller's request.
    throw new Error("MeeTar translation policy could not be applied");
  }
  if (ctx.signal?.aborted) return;

  const id = randomUUID();
  try {
    recordRequest(files.database, {
      id,
      createdAt: new Date().toISOString(),
      protocol: ctx.protocol,
      model: body.model,
      agent: ctx.agent ?? "",
      session: ctx.session ?? "",
      origin: ctx.origin,
      query: ctx.query ?? "",
      policyId: policy.id,
      policy: policy.snapshot,
      originalRequest: body,
      effectiveRequest,
    });
    ctx.state.meetarTranslation = { id, database: files.database };
  } catch {
    // A storage fault must not stop translation or remove terminology guidance.
    report(ctx, "request_storage_error");
  }
  return effectiveRequest;
}

/** Observe the final client reply; never rewrite it or call another model. */
export async function onResponse(reply, ctx) {
  const record = ctx.state?.meetarTranslation;
  if (!record) return;
  try {
    recordResponse(record.database, record.id, {
      reply,
      success: ctx.success === true,
      responseText: responseText(reply),
      completedAt: new Date().toISOString(),
    });
  } catch {
    report(ctx, "response_storage_error");
  }
}

function responseText(reply) {
  if (!Array.isArray(reply?.choices)) return null;
  return reply.choices.map((choice) => {
    const content = choice?.message?.content;
    if (typeof content === "string") return content;
    if (Array.isArray(content)) {
      return content.filter((part) => part?.type === "text" && typeof part.text === "string")
        .map((part) => part.text).join("");
    }
    return "";
  }).join("\n");
}

function report(ctx, code) {
  // Diagnostic codes only: never expose request content or configuration values.
  try {
    const outcome = code === "policy_error" ? "invalid" : code === "unsupported_protocol" ? "skipped" : "unavailable";
    ctx.report?.(outcome, 0);
  } catch {
    // Reporting is best effort, like the gateway's completion notification.
  }
  console.error(`[meetar-translation] ${code}`);
}
