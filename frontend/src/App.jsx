import React, { useEffect, useMemo, useState } from 'react';
import { backend } from 'declarations/backend';

const I18N = {
  zh: {
    title: 'OpenClaw on ICP（最小可用）',
    session: '会话',
    provider: '提供方',
    model: '模型',
    apiKey: 'API Key',
    refresh: '刷新',
    reset: '重置会话',
    message: '消息',
    messagePh: '输入消息，然后点发送…',
    send: '发送',
    sending: '发送中…',
    done: '完成',
    resetIng: '重置中…',
    resetDone: '已重置',
    errPrefix: '错误：',
    exPrefix: '异常：',
    needModel: 'model 不能为空',
    needKey: 'apiKey 不能为空',
    needMsg: 'message 不能为空',
    lang: 'English',
  },
  en: {
    title: 'OpenClaw on ICP (minimal)',
    session: 'Session',
    provider: 'Provider',
    model: 'Model',
    apiKey: 'API Key',
    refresh: 'Refresh',
    reset: 'Reset session',
    message: 'Message',
    messagePh: 'Type a message, then click Send…',
    send: 'Send',
    sending: 'Sending…',
    done: 'Done',
    resetIng: 'Resetting…',
    resetDone: 'Reset',
    errPrefix: 'Error: ',
    exPrefix: 'Exception: ',
    needModel: 'Model is required',
    needKey: 'API key is required',
    needMsg: 'Message is required',
    lang: '中文',
  },
};

function providerVariant(provider) {
  if (provider === 'anthropic') return { anthropic: null };
  if (provider === 'google') return { google: null };
  return { openai: null };
}

function toMs(tsNs) {
  // Motoko Int comes through as BigInt in JS bindings.
  if (typeof tsNs === 'bigint') return Number(tsNs / 1_000_000n);
  return Math.floor(Number(tsNs) / 1_000_000);
}

export default function App() {
  const [lang, setLang] = useState('zh');
  const t = useMemo(() => I18N[lang] ?? I18N.zh, [lang]);

  const [sessionId, setSessionId] = useState('main');
  const [provider, setProvider] = useState('openai');
  const [model, setModel] = useState('gpt-4o-mini');
  const [apiKey, setApiKey] = useState('');
  const [message, setMessage] = useState('');

  const [googleModels, setGoogleModels] = useState([]);
  const [googleModelsLoading, setGoogleModelsLoading] = useState(false);

  const [history, setHistory] = useState([]);
  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);

  async function refresh(nextSessionId = sessionId) {
    const sid = (nextSessionId || 'main').trim() || 'main';
    setSessionId(sid);
    const h = await backend.sessions_history(sid, 50);
    setHistory(h);
  }

  async function sendMessage() {
    const sid = (sessionId || 'main').trim() || 'main';

    if (!model.trim()) return setStatus(t.needModel);
    if (!apiKey.trim()) return setStatus(t.needKey);
    if (!message.trim()) return setStatus(t.needMsg);

    setBusy(true);
    setStatus(t.sending);

    const opts = {
      provider: providerVariant(provider),
      model: model.trim(),
      apiKey: apiKey.trim(),
      systemPrompt: [],
      maxTokens: [],
      temperature: [],
      skillNames: [],
      includeHistory: true,
    };

    try {
      const res = await backend.sessions_send(sid, message, opts);
      if ('ok' in res) {
        setMessage('');
        await refresh(sid);
        setStatus(t.done);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function resetSession() {
    const sid = (sessionId || 'main').trim() || 'main';
    setBusy(true);
    setStatus(t.resetIng);
    try {
      await backend.sessions_reset(sid);
      await refresh(sid);
      setStatus(t.resetDone);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void refresh('main');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // Provide a sensible default when switching provider.
    if (provider === 'google' && model === 'gpt-4o-mini') setModel('gemini-1.5-flash');
  }, [provider]);

  useEffect(() => {
    let cancelled = false;
    async function loadGoogleModels() {
      if (provider !== 'google') return;
      if (!apiKey.trim()) {
        setGoogleModels([]);
        return;
      }

      setGoogleModelsLoading(true);
      try {
        const res = await backend.models_list(providerVariant('google'), apiKey.trim());
        if (cancelled) return;
        if ('ok' in res) {
          const models = res.ok || [];
          setGoogleModels(models);
          if (models.length > 0) setModel(models[0]);
        } else {
          setGoogleModels([]);
          setStatus(`${t.errPrefix}${res.err}`);
        }
      } catch (e) {
        if (!cancelled) setStatus(`${t.exPrefix}${String(e)}`);
      } finally {
        if (!cancelled) setGoogleModelsLoading(false);
      }
    }

    void loadGoogleModels();
    return () => {
      cancelled = true;
    };
  }, [provider, apiKey, lang]);

  return (
    <main>
      <div className="langToggle">
        <button type="button" onClick={() => setLang((v) => (v === 'zh' ? 'en' : 'zh'))}>
          {t.lang}
        </button>
      </div>

      <h2>{t.title}</h2>

      <div className="row" style={{ margin: '10px 0 14px' }}>
        <label htmlFor="sessionId">{t.session}</label>
        <input
          id="sessionId"
          type="text"
          value={sessionId}
          onChange={(e) => setSessionId(e.target.value)}
          style={{ minWidth: 220 }}
        />

        <label htmlFor="provider">{t.provider}</label>
        <select id="provider" value={provider} onChange={(e) => setProvider(e.target.value)}>
          <option value="openai">OpenAI</option>
          <option value="anthropic">Anthropic</option>
          <option value="google">Google (Gemini)</option>
        </select>

        <label htmlFor="model">{t.model}</label>
        {provider === 'google' ? (
          <select
            id="model"
            value={model}
            onChange={(e) => setModel(e.target.value)}
            disabled={googleModelsLoading || googleModels.length === 0}
            style={{ minWidth: 260 }}
          >
            {googleModels.length === 0 ? (
              <option value="">{googleModelsLoading ? 'Loading…' : '—'}</option>
            ) : (
              googleModels.map((m) => (
                <option value={m} key={m}>
                  {m}
                </option>
              ))
            )}
          </select>
        ) : (
          <input id="model" type="text" value={model} onChange={(e) => setModel(e.target.value)} style={{ minWidth: 260 }} />
        )}

        <label htmlFor="apiKey">{t.apiKey}</label>
        <input
          id="apiKey"
          type="password"
          value={apiKey}
          onChange={(e) => setApiKey(e.target.value)}
          placeholder="sk-… / anthropic-…"
          style={{ minWidth: 260 }}
        />

        <button type="button" onClick={() => void refresh()} disabled={busy}>
          {t.refresh}
        </button>
        <button type="button" onClick={() => void resetSession()} disabled={busy}>
          {t.reset}
        </button>
      </div>

      <div>
        <label htmlFor="message">{t.message}</label>
        <textarea id="message" value={message} onChange={(e) => setMessage(e.target.value)} placeholder={t.messagePh} />
        <div className="row" style={{ marginTop: 10 }}>
          <button type="button" onClick={() => void sendMessage()} disabled={busy}>
            {t.send}
          </button>
          <div className="status">{status}</div>
        </div>
      </div>

      <div className="chat">
        {history.map((m, idx) => {
          const role = Object.keys(m.role)[0];
          return (
            <div className="msg" key={idx}>
              <div className="meta">
                {role} · {new Date(toMs(m.tsNs)).toLocaleString()}
              </div>
              <div>{m.content}</div>
            </div>
          );
        })}
      </div>
    </main>
  );
}
