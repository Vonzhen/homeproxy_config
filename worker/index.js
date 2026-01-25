/**
 * HPCC - 积木包 A：云端指挥中心 (Worker)
 * 严格遵循原始功能：Token 鉴权 + KV 信号 + TG 交互 + Sub-Store 中转
 */

const validateToken = (url, env) => {
  const token = url.searchParams.get("token");
  return token === env.AUTH_TOKEN;
};

const signalManager = {
  // 获取当前云端版本号
  async getCurrent(env) {
    return await env.KV.get("GLOBAL_UPDATE_TICK") || "0";
  },
  // 手动更新信号（网页触发）
  async manualUpdate(env) {
    const tick = Date.now().toString();
    await env.KV.put("GLOBAL_UPDATE_TICK", tick);
    return tick;
  },
  // 从 TG 消息同步信号 (严格保留原始逻辑)
  async syncWithTG(env) {
    let currentKVTick = await this.getCurrent(env);
    try {
      const tgRes = await fetch(`https://api.telegram.org/bot${env.TG_TOKEN}/getUpdates?offset=-1`);
      const data = await tgRes.json();
      const lastMsg = data.result?.[0]?.message;

      if (lastMsg?.text === "/update" && lastMsg.from.id.toString() === env.TG_CHAT_ID) {
        const tgTick = lastMsg.date.toString();
        if (parseInt(tgTick) > parseInt(currentKVTick.substring(0, 10))) {
          await env.KV.put("GLOBAL_UPDATE_TICK", tgTick);
          return tgTick;
        }
      }
    } catch (e) {
      console.error("TG Sync Error:", e);
    }
    return currentKVTick;
  }
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // 1. 严格鉴权
    if (!validateToken(url, env)) {
      return new Response("Unauthorized", { status: 401 });
    }

    // 2. 原始逻辑路由
    switch (url.pathname) {
      // 触发更新
      case "/update":
        const newTick = await signalManager.manualUpdate(env);
        return new Response(`🚀 信号已同步！\nTick: ${newTick}`);

      // OP 端轮询信号
      case "/tg-sync":
        const syncTick = await signalManager.syncWithTG(env);
        return new Response(syncTick);

      // 拉取节点数据
      case "/fetch-nodes":
        try {
          const res = await fetch(env.SUB_STORE_API);
          if (!res.ok) throw new Error("Sub-Store API Offline");
          const nodeData = await res.text();
          return new Response(nodeData, { 
            headers: { "Content-Type": "application/json; charset=utf-8" } 
          });
        } catch (e) {
          return new Response(e.message, { status: 500 });
        }

      default:
        return new Response("🏢 HPCC Cloud Module is Active.");
    }
  }
};
