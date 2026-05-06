export async function onRequestGet({ env }) {
  return new Response(
    JSON.stringify({
      ok: true,
      turnstileSiteKey: env.TURNSTILE_SITE_KEY || null
    }),
    {
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store"
      }
    }
  );
}
