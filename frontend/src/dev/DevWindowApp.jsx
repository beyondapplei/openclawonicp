import React, { useEffect, useMemo, useState } from 'react';
import {
  readDevWindowState,
  subscribeDevWindowState,
} from '../devWindowSync';

const I18N = {
  zh: {
    title: '开发窗口（消息全文）',
    lang: 'English',
    back: '返回主界面',
    events: '事件日志',
    history: '会话历史',
    noEvents: '暂无事件',
    noHistory: '暂无历史消息',
    updatedAt: '最后更新',
    clear: '清空日志',
  },
  en: {
    title: 'Dev Window (Full Messages)',
    lang: '中文',
    back: 'Back',
    events: 'Event Log',
    history: 'Session History',
    noEvents: 'No events yet',
    noHistory: 'No history yet',
    updatedAt: 'Last Updated',
    clear: 'Clear',
  },
};

function toLocalTime(tsMs) {
  return new Date(Number(tsMs || Date.now())).toLocaleString();
}

function toMsFromNsString(tsNs) {
  const raw = String(tsNs || '');
  if (!raw) return Date.now();
  const ns = Number(raw);
  if (!Number.isFinite(ns)) return Date.now();
  return Math.floor(ns / 1_000_000);
}

export default function DevWindowApp() {
  const [lang, setLang] = useState('zh');
  const t = useMemo(() => I18N[lang] ?? I18N.zh, [lang]);

  const [state, setState] = useState(() => readDevWindowState());

  useEffect(() => {
    const stop = subscribeDevWindowState((next) => setState(next));
    return () => stop();
  }, []);

  useEffect(() => {
    document.body.classList.add('devFullscreenBody');
    return () => {
      document.body.classList.remove('devFullscreenBody');
    };
  }, []);

  const sortedEvents = useMemo(() => {
    const arr = Array.isArray(state.events) ? [...state.events] : [];
    arr.sort((a, b) => Number(b.tsMs || 0) - Number(a.tsMs || 0));
    return arr;
  }, [state.events]);

  const sortedHistory = useMemo(() => {
    const arr = Array.isArray(state.history) ? [...state.history] : [];
    arr.sort((a, b) => Number(a.tsNs || 0) - Number(b.tsNs || 0));
    return arr;
  }, [state.history]);

  function clearLogs() {
    window.localStorage.removeItem('agentonicp.dev_window.state.v1');
    setState(readDevWindowState());
  }

  return (
    <main className="devPage">
      <div className="topBar langToggle">
        <button type="button" onClick={() => { window.location.href = 'index.html'; }} style={{ marginRight: 8 }}>
          {t.back}
        </button>
        <button type="button" onClick={() => setLang((v) => (v === 'zh' ? 'en' : 'zh'))} style={{ marginRight: 8 }}>
          {t.lang}
        </button>
        <button type="button" onClick={clearLogs}>
          {t.clear}
        </button>
      </div>

      <h2 className="pageTitle">{t.title}</h2>
      <section className="panel" style={{ marginBottom: 14 }}>
        <div className="status">
          {t.updatedAt}: {toLocalTime(state.updatedAtMs)}
        </div>
      </section>

      <section className="panel" style={{ marginBottom: 14 }}>
        <h3>{t.events}</h3>
        {sortedEvents.length === 0 ? (
          <div className="status">{t.noEvents}</div>
        ) : (
          <div className="chat">
            {sortedEvents.map((e) => (
              <div className="msg" key={e.id}>
                <div className="meta">
                  {e.type} · {toLocalTime(e.tsMs)} · {e.provider}/{e.model}
                </div>
                <div className="fullContent">{e.content}</div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="panel">
        <h3>{t.history}</h3>
        {sortedHistory.length === 0 ? (
          <div className="status">{t.noHistory}</div>
        ) : (
          <div className="chat">
            {sortedHistory.map((m) => (
              <div className="msg" key={m.id}>
                <div className="meta">
                  {m.role} · {toLocalTime(toMsFromNsString(m.tsNs))}
                </div>
                <div className="fullContent">{m.content}</div>
              </div>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
