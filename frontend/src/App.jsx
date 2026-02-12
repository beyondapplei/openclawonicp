import React, { useEffect, useMemo, useState } from 'react';
import { initAuth, loginWithII, logoutII } from './auth';

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
    admin: '管理界面',
    login: 'Identity 登录',
    logout: '退出登录',
    wallet: '钱包',
    principal: 'Principal',
    canisterId: '后端 Canister ID',
    icpRecv: 'ICP 接受地址',
    ethWallet: 'Agent ETH 钱包',
    toPrincipal: '目标 Principal',
    amountE8s: '金额 (e8s)',
    sendIcp: '发送 ICP',
    sendEth: '发送 ETH',
    sendIcrc1: '发送 ICRC1',
    sendErc20: '发送 ERC20',
    refreshBalances: '刷新余额',
    ethNet: 'ETH 网络',
    rpcUrl: 'RPC URL（可选）',
    ethTo: 'ETH 目标地址',
    ethAmount: 'ETH 数量',
    erc20Token: 'ERC20 合约地址',
    erc20To: 'ERC20 目标地址',
    erc20Amount: 'ERC20 数量(最小单位)',
    balances: '余额',
    balIcp: 'ICP 余额(e8s)',
    balEth: 'ETH 余额(wei)',
    balIcrc1: 'ICRC1 余额',
    balErc20: 'ERC20 余额',
    icrc1Ledger: 'ICRC1 Ledger Principal',
    icrc1Amount: 'ICRC1 金额',
    icrc1Fee: 'ICRC1 Fee（可选）',
    needLedger: 'Ledger Principal 不能为空',
    needIcrc1Amount: 'ICRC1 金额必须大于 0',
    needErc20Token: 'ERC20 合约地址不能为空',
    needErc20To: 'ERC20 目标地址不能为空',
    needErc20Amount: 'ERC20 数量必须大于 0',
    needTo: '目标 Principal 不能为空',
    needAmount: '金额必须大于 0',
    needEthTo: 'ETH 目标地址不能为空',
    needEthAmount: 'ETH 数量必须大于 0',
    authLoading: '身份初始化中…',
    notOwnerLogin: '不是 agent 的拥有者，不能登录',
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
    admin: 'Admin',
    login: 'Login with Identity',
    logout: 'Logout',
    wallet: 'Wallet',
    principal: 'Principal',
    canisterId: 'Backend Canister ID',
    icpRecv: 'ICP Receive Address',
    ethWallet: 'Agent ETH Wallet',
    toPrincipal: 'To Principal',
    amountE8s: 'Amount (e8s)',
    sendIcp: 'Send ICP',
    sendEth: 'Send ETH',
    sendIcrc1: 'Send ICRC1',
    sendErc20: 'Send ERC20',
    refreshBalances: 'Refresh Balances',
    ethNet: 'ETH Network',
    rpcUrl: 'RPC URL (optional)',
    ethTo: 'ETH Destination',
    ethAmount: 'ETH Amount',
    erc20Token: 'ERC20 Token Address',
    erc20To: 'ERC20 Destination',
    erc20Amount: 'ERC20 Amount (base unit)',
    balances: 'Balances',
    balIcp: 'ICP Balance (e8s)',
    balEth: 'ETH Balance (wei)',
    balIcrc1: 'ICRC1 Balance',
    balErc20: 'ERC20 Balance',
    icrc1Ledger: 'ICRC1 Ledger Principal',
    icrc1Amount: 'ICRC1 Amount',
    icrc1Fee: 'ICRC1 Fee (optional)',
    needLedger: 'Ledger principal is required',
    needIcrc1Amount: 'ICRC1 amount must be greater than 0',
    needErc20Token: 'ERC20 token address is required',
    needErc20To: 'ERC20 destination is required',
    needErc20Amount: 'ERC20 amount must be greater than 0',
    needTo: 'Destination principal is required',
    needAmount: 'Amount must be greater than 0',
    needEthTo: 'ETH destination is required',
    needEthAmount: 'ETH amount must be greater than 0',
    authLoading: 'Initializing identity…',
    notOwnerLogin: 'Not the agent owner. Login denied.',
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
  const SESSION_ID = 'main';
  const [lang, setLang] = useState('zh');
  const t = useMemo(() => I18N[lang] ?? I18N.zh, [lang]);

  const [authClient, setAuthClient] = useState(null);
  const [actor, setActor] = useState(null);
  const [isAuthed, setIsAuthed] = useState(false);
  const [principalText, setPrincipalText] = useState('');
  const [canisterIdText, setCanisterIdText] = useState('');
  const [authLoading, setAuthLoading] = useState(true);
  const [ownerPrincipalText, setOwnerPrincipalText] = useState('');

  const [provider, setProvider] = useState('openai');
  const [model, setModel] = useState('gpt-4o-mini');
  const [apiKey, setApiKey] = useState('');
  const [message, setMessage] = useState('');

  const [googleModels, setGoogleModels] = useState([]);
  const [googleModelsLoading, setGoogleModelsLoading] = useState(false);

  const [history, setHistory] = useState([]);
  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);

  function principalToText(p) {
    if (!p) return '';
    if (typeof p.toText === 'function') return p.toText();
    return String(p);
  }

  async function refreshOwnerAccess(a, principalHint = '', client = authClient) {
    if (!a) {
      setOwnerPrincipalText('');
      return;
    }
    try {
      if (principalHint.trim()) {
        const me = await a.whoami();
        setOwnerPrincipalText(principalToText(me));
        return;
      }
      const ownerRes = await a.owner_get();
      const ownerText = ownerRes?.[0] ? principalToText(ownerRes[0]) : '';
      setOwnerPrincipalText(ownerText);
    } catch (e) {
      if (principalHint.trim()) {
        if (client) {
          const logoutRes = await logoutII(client);
          setActor(logoutRes.actor);
        }
        setIsAuthed(false);
        setPrincipalText('');
        setCanisterIdText('');
        setStatus(t.notOwnerLogin);
        return;
      }
      setOwnerPrincipalText('');
    }
  }

  async function refreshWallet(a = actor) {
    if (!a || !isAuthed) {
      setCanisterIdText('');
      return;
    }
    try {
      const cid = await a.canister_principal();
      setCanisterIdText(String(cid));
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    }
  }

  async function refresh() {
    if (!actor) return;
    const h = await actor.sessions_history(SESSION_ID, 50);
    setHistory(h);
  }

  async function sendMessage() {
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
      if (!actor) throw new Error('backend actor not ready');
      const res = await actor.sessions_send(SESSION_ID, message, opts);
      if ('ok' in res) {
        setMessage('');
        await refresh();
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
    setBusy(true);
    setStatus(t.resetIng);
    try {
      if (!actor) throw new Error('backend actor not ready');
      await actor.sessions_reset(SESSION_ID);
      await refresh();
      setStatus(t.resetDone);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    let cancelled = false;
    async function bootstrap() {
      setAuthLoading(true);
      try {
        const auth = await initAuth();
        if (cancelled) return;
        setAuthClient(auth.client);
        if (auth.isAuthenticated && auth.actor && auth.principalText) {
          try {
            const ownerText = await auth.actor.whoami();
            if (cancelled) return;
            setActor(auth.actor);
            setIsAuthed(true);
            setPrincipalText(auth.principalText);
            setOwnerPrincipalText(principalToText(ownerText));
          } catch (_) {
            const logoutRes = await logoutII(auth.client);
            if (cancelled) return;
            setActor(logoutRes.actor);
            setIsAuthed(false);
            setPrincipalText('');
            setOwnerPrincipalText('');
            setCanisterIdText('');
            setStatus(t.notOwnerLogin);
          }
        } else {
          setActor(auth.actor);
          setIsAuthed(false);
          setPrincipalText('');
          await refreshOwnerAccess(auth.actor, '', auth.client);
        }
      } finally {
        if (!cancelled) setAuthLoading(false);
      }
    }
    void bootstrap();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!actor || !isAuthed) return;
    void refresh();
    void refreshWallet(actor);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [actor, isAuthed, authClient]);

  useEffect(() => {
    // Provide a sensible default when switching provider.
    if (provider === 'google' && model === 'gpt-4o-mini') setModel('gemini-1.5-flash');
  }, [provider]);

  useEffect(() => {
    let cancelled = false;
    async function loadGoogleModels() {
      if (!actor) return;
      if (provider !== 'google') return;
      if (!apiKey.trim()) {
        setGoogleModels([]);
        return;
      }

      setGoogleModelsLoading(true);
      try {
        const res = await actor.models_list(providerVariant('google'), apiKey.trim());
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
  }, [provider, apiKey, lang, actor]);

  async function login() {
    if (!authClient) return;
    setBusy(true);
    try {
      const r = await loginWithII(authClient);

      try {
        await r.actor.whoami();
      } catch (_) {
        const logoutRes = await logoutII(authClient);
        setActor(logoutRes.actor);
        setIsAuthed(false);
        setPrincipalText('');
        setCanisterIdText('');
        setOwnerPrincipalText('');
        setStatus(t.notOwnerLogin);
        return;
      }

      setActor(r.actor);
      setIsAuthed(true);
      setPrincipalText(r.principalText);
      setOwnerPrincipalText(r.principalText);
      setStatus(t.done);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function logout() {
    if (!authClient) return;
    setBusy(true);
    try {
      const r = await logoutII(authClient);
      setActor(r.actor);
      setIsAuthed(false);
      setPrincipalText('');
      setCanisterIdText('');
      await refreshOwnerAccess(r.actor, '');
      setStatus(t.done);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  function openAdminPage() {
    window.location.href = 'admin.html';
  }

  function openWalletPage() {
    window.location.href = 'wallet.html';
  }

  const canAccess = !!(isAuthed && principalText && ownerPrincipalText && principalText === ownerPrincipalText);
  const showLoginOnly = !authLoading && !canAccess;

  if (showLoginOnly) {
    return (
      <main className="loginGate">
        <button className="loginGateButton" type="button" onClick={() => void login()} disabled={busy}>
          {t.login}
        </button>
        {status ? <div className="loginGateStatus">{status}</div> : null}
      </main>
    );
  }

  return (
    <main className="appShell">
      <div className="topBar langToggle">
        {isAuthed && principalText ? (
          <span className="principalBadge">
            {t.principal}: {ownerPrincipalText || principalText}
          </span>
        ) : null}
        {!authLoading && (
          isAuthed ? (
            <button type="button" onClick={() => void logout()} style={{ marginRight: 8 }}>
              {t.logout}
            </button>
          ) : (
            <button type="button" onClick={() => void login()} style={{ marginRight: 8 }}>
              {t.login}
            </button>
          )
        )}
        <button type="button" onClick={openAdminPage} style={{ marginRight: 8 }}>
          {t.admin}
        </button>
        <button type="button" onClick={openWalletPage} style={{ marginRight: 8 }}>
          {t.wallet}
        </button>
        <button type="button" onClick={() => setLang((v) => (v === 'zh' ? 'en' : 'zh'))}>
          {t.lang}
        </button>
      </div>

      <h2 className="pageTitle">{t.title}</h2>

      <section className="panel" style={{ marginBottom: 12 }}>
        {authLoading ? (
          <div className="status">{t.authLoading}</div>
        ) : (
          <>
            <div className="status"><strong>{t.principal}:</strong> {ownerPrincipalText || '-'}</div>
            <div className="status"><strong>{t.canisterId}:</strong> {canisterIdText || '-'}</div>
          </>
        )}
      </section>

      <section className="panel">
      <div className="row" style={{ margin: '10px 0 14px' }}>
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
      </section>

      <div className="chat panel">
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
