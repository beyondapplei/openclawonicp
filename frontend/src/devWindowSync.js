const STORAGE_KEY = 'openclaw.dev_window.state.v1';
const CHANNEL_NAME = 'openclaw.dev_window.channel.v1';
const MAX_EVENTS = 200;

let channel = null;

function isBrowser() {
  return typeof window !== 'undefined';
}

function getChannel() {
  if (!isBrowser()) return null;
  if (typeof BroadcastChannel === 'undefined') return null;
  if (!channel) channel = new BroadcastChannel(CHANNEL_NAME);
  return channel;
}

function parseRole(role) {
  if (!role) return '';
  if (typeof role === 'string') return role;
  const keys = Object.keys(role);
  return keys.length > 0 ? keys[0] : '';
}

function parseTsNs(tsNs) {
  if (typeof tsNs === 'bigint') return tsNs.toString();
  if (typeof tsNs === 'number') return String(Math.floor(tsNs));
  if (typeof tsNs === 'string') return tsNs;
  return '';
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) return [];
  return history.map((msg, idx) => ({
    id: `${parseTsNs(msg?.tsNs)}-${idx}`,
    role: parseRole(msg?.role),
    content: typeof msg?.content === 'string' ? msg.content : String(msg?.content ?? ''),
    tsNs: parseTsNs(msg?.tsNs),
  }));
}

function defaultState() {
  return {
    version: 1,
    updatedAtMs: Date.now(),
    history: [],
    events: [],
  };
}

export function readDevWindowState() {
  if (!isBrowser()) return defaultState();
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaultState();
    const parsed = JSON.parse(raw);
    return {
      version: 1,
      updatedAtMs: Number(parsed?.updatedAtMs ?? Date.now()),
      history: Array.isArray(parsed?.history) ? parsed.history : [],
      events: Array.isArray(parsed?.events) ? parsed.events : [],
    };
  } catch (_) {
    return defaultState();
  }
}

function writeDevWindowState(next) {
  if (!isBrowser()) return;
  const state = {
    version: 1,
    updatedAtMs: Date.now(),
    history: Array.isArray(next?.history) ? next.history : [],
    events: Array.isArray(next?.events) ? next.events.slice(-MAX_EVENTS) : [],
  };
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  const bc = getChannel();
  if (bc) bc.postMessage({ kind: 'state', state });
}

export function publishHistoryToDevWindow(history) {
  const current = readDevWindowState();
  writeDevWindowState({
    ...current,
    history: normalizeHistory(history),
  });
}

export function publishEventToDevWindow(params) {
  const current = readDevWindowState();
  const event = {
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    type: typeof params?.type === 'string' ? params.type : 'info',
    content: typeof params?.content === 'string' ? params.content : String(params?.content ?? ''),
    sessionId: typeof params?.sessionId === 'string' ? params.sessionId : '',
    provider: typeof params?.provider === 'string' ? params.provider : '',
    model: typeof params?.model === 'string' ? params.model : '',
    tsMs: Date.now(),
  };
  writeDevWindowState({
    ...current,
    events: [...current.events, event],
  });
}

export function subscribeDevWindowState(onState) {
  if (!isBrowser()) return () => {};

  const applyRaw = (raw) => {
    try {
      const parsed = JSON.parse(raw);
      if (parsed?.version !== 1) return;
      onState({
        version: 1,
        updatedAtMs: Number(parsed?.updatedAtMs ?? Date.now()),
        history: Array.isArray(parsed?.history) ? parsed.history : [],
        events: Array.isArray(parsed?.events) ? parsed.events : [],
      });
    } catch (_) {
      // Ignore malformed payload.
    }
  };

  const onStorage = (e) => {
    if (e.key !== STORAGE_KEY || !e.newValue) return;
    applyRaw(e.newValue);
  };
  window.addEventListener('storage', onStorage);

  const bc = getChannel();
  const onMessage = (e) => {
    if (e?.data?.kind !== 'state') return;
    const state = e.data.state;
    onState({
      version: 1,
      updatedAtMs: Number(state?.updatedAtMs ?? Date.now()),
      history: Array.isArray(state?.history) ? state.history : [],
      events: Array.isArray(state?.events) ? state.events : [],
    });
  };
  if (bc) bc.addEventListener('message', onMessage);

  return () => {
    window.removeEventListener('storage', onStorage);
    if (bc) bc.removeEventListener('message', onMessage);
  };
}
