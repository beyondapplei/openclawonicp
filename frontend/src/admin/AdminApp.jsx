import React, { useEffect, useMemo, useState } from 'react';
import { initAuth, loginWithII, logoutII } from '../auth';

const I18N = {
  zh: {
    title: 'Telegram 管理',
    back: '返回聊天页',
    lang: 'English',
    status: '当前状态',
    refresh: '刷新状态',
    configured: '已配置 Bot',
    hasSecret: '已配置 Secret',
    hasLlmConfig: '已配置默认 LLM',
    tgConfig: 'Telegram 配置',
    botToken: 'Bot Token',
    secretToken: 'Secret Token（可选）',
    saveTg: '保存 TG 配置',
    llmConfig: '默认 LLM 配置（用于 TG）',
    provider: 'Provider',
    model: 'Model',
    apiKey: 'API Key',
    systemPrompt: 'System Prompt（可选）',
    includeHistory: '包含历史上下文',
    saveLlm: '保存默认 LLM',
    webhook: 'Webhook 配置',
    webhookUrl: 'Webhook URL',
    setWebhook: '设置 Webhook',
    skills: '后端技能',
    loadSkills: '加载后端技能',
    skillList: '技能列表',
    noSkills: '暂无技能',
    skillDetail: '技能详情',
    ok: '完成',
    errPrefix: '错误：',
    exPrefix: '异常：',
    required: '请填写必填项',
    login: 'Identity 登录',
    logout: '退出登录',
    principal: 'Principal',
    authLoading: '身份初始化中…',
    notOwnerLogin: '不是 agent 的拥有者，不能登录',
  },
  en: {
    title: 'Telegram Admin',
    back: 'Back to chat',
    lang: '中文',
    status: 'Current status',
    refresh: 'Refresh status',
    configured: 'Bot configured',
    hasSecret: 'Secret configured',
    hasLlmConfig: 'Default LLM configured',
    tgConfig: 'Telegram config',
    botToken: 'Bot Token',
    secretToken: 'Secret Token (optional)',
    saveTg: 'Save TG config',
    llmConfig: 'Default LLM config (for TG)',
    provider: 'Provider',
    model: 'Model',
    apiKey: 'API Key',
    systemPrompt: 'System Prompt (optional)',
    includeHistory: 'Include history context',
    saveLlm: 'Save default LLM',
    webhook: 'Webhook config',
    webhookUrl: 'Webhook URL',
    setWebhook: 'Set Webhook',
    skills: 'Backend Skills',
    loadSkills: 'Load backend skills',
    skillList: 'Skill list',
    noSkills: 'No skills',
    skillDetail: 'Skill detail',
    ok: 'Done',
    errPrefix: 'Error: ',
    exPrefix: 'Exception: ',
    required: 'Please fill required fields',
    login: 'Login with Identity',
    logout: 'Logout',
    principal: 'Principal',
    authLoading: 'Initializing identity…',
    notOwnerLogin: 'Not the agent owner. Login denied.',
  },
};

function providerVariant(provider) {
  if (provider === 'anthropic') return { anthropic: null };
  if (provider === 'google') return { google: null };
  return { openai: null };
}

export default function AdminApp() {
  const [lang, setLang] = useState('zh');
  const t = useMemo(() => I18N[lang] ?? I18N.zh, [lang]);

  const [authClient, setAuthClient] = useState(null);
  const [actor, setActor] = useState(null);
  const [isAuthed, setIsAuthed] = useState(false);
  const [principalText, setPrincipalText] = useState('');
  const [authLoading, setAuthLoading] = useState(true);
  const [ownerPrincipalText, setOwnerPrincipalText] = useState('');

  const [status, setStatus] = useState('');
  const [tgStatus, setTgStatus] = useState(null);

  const [botToken, setBotToken] = useState('');
  const [secretToken, setSecretToken] = useState('');

  const [provider, setProvider] = useState('google');
  const [model, setModel] = useState('gemini-1.5-flash');
  const [apiKey, setApiKey] = useState('');
  const [systemPrompt, setSystemPrompt] = useState('');
  const [includeHistory, setIncludeHistory] = useState(true);

  const [webhookUrl, setWebhookUrl] = useState('');

  const [skills, setSkills] = useState([]);
  const [selectedSkill, setSelectedSkill] = useState('');
  const [skillDetail, setSkillDetail] = useState('');

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
    } catch (_) {
      if (principalHint.trim()) {
        if (client) {
          const logoutRes = await logoutII(client);
          setActor(logoutRes.actor);
        }
        setIsAuthed(false);
        setPrincipalText('');
        setStatus(t.notOwnerLogin);
        return;
      }
      setOwnerPrincipalText('');
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
        setOwnerPrincipalText('');
        setStatus(t.notOwnerLogin);
        return;
      }

      setActor(r.actor);
      setIsAuthed(true);
      setPrincipalText(r.principalText);
      setOwnerPrincipalText(r.principalText);
      setStatus(t.ok);
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
      await refreshOwnerAccess(r.actor, '');
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function refreshStatus() {
    if (!actor) return;
    setBusy(true);
    try {
      const s = await actor.tg_status();
      setTgStatus(s);
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function saveTgConfig() {
    if (!actor) return;
    if (!botToken.trim()) {
      setStatus(t.required);
      return;
    }
    setBusy(true);
    try {
      await actor.admin_set_tg(botToken.trim(), secretToken.trim() ? [secretToken.trim()] : []);
      setStatus(t.ok);
      await refreshStatus();
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
      setBusy(false);
    }
  }

  async function saveLlmConfig() {
    if (!actor) return;
    if (!model.trim() || !apiKey.trim()) {
      setStatus(t.required);
      return;
    }
    setBusy(true);
    try {
      await actor.admin_set_llm_opts({
        provider: providerVariant(provider),
        model: model.trim(),
        apiKey: apiKey.trim(),
        systemPrompt: systemPrompt.trim() ? [systemPrompt.trim()] : [],
        maxTokens: [],
        temperature: [],
        skillNames: [],
        includeHistory,
      });
      setStatus(t.ok);
      await refreshStatus();
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
      setBusy(false);
    }
  }

  async function setWebhook() {
    if (!actor) return;
    if (!webhookUrl.trim()) {
      setStatus(t.required);
      return;
    }
    setBusy(true);
    try {
      const res = await actor.admin_tg_set_webhook(webhookUrl.trim());
      if ('ok' in res) {
        setStatus(t.ok);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function loadSkills() {
    if (!actor) return;
    setBusy(true);
    try {
      const list = await actor.skills_list();
      setSkills(list);
      setSelectedSkill('');
      setSkillDetail('');
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function loadSkillDetail(name) {
    if (!actor) return;
    setBusy(true);
    try {
      const detail = await actor.skills_get(name);
      setSelectedSkill(name);
      setSkillDetail(detail?.[0] ?? '');
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
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
        <button type="button" onClick={() => (window.location.href = './')} style={{ marginRight: 8 }}>
          {t.back}
        </button>
        <button type="button" onClick={() => setLang((v) => (v === 'zh' ? 'en' : 'zh'))}>
          {t.lang}
        </button>
      </div>

      <h2 className="pageTitle">{t.title}</h2>

      <section className="panel" style={{ marginBottom: 16 }}>
        {authLoading ? (
          <div className="status">{t.authLoading}</div>
        ) : (
          <div className="status"><strong>{t.principal}:</strong> {principalText || 'anonymous'}</div>
        )}
      </section>

      <section className="panel" style={{ marginBottom: 16 }}>
        <h3>{t.status}</h3>
        <button type="button" onClick={() => void refreshStatus()} disabled={busy}>
          {t.refresh}
        </button>
        <div className="status" style={{ marginTop: 8 }}>
          {tgStatus && (
            <div>
              <div>{t.configured}: {String(tgStatus.configured)}</div>
              <div>{t.hasSecret}: {String(tgStatus.hasSecret)}</div>
              <div>{t.hasLlmConfig}: {String(tgStatus.hasLlmConfig)}</div>
            </div>
          )}
          <div>{status}</div>
        </div>
      </section>

      <section className="panel" style={{ marginBottom: 16 }}>
        <h3>{t.tgConfig}</h3>
        <div className="row">
          <label>{t.botToken}</label>
          <input type="password" value={botToken} onChange={(e) => setBotToken(e.target.value)} style={{ minWidth: 460 }} />
        </div>
        <div className="row" style={{ marginTop: 8 }}>
          <label>{t.secretToken}</label>
          <input type="text" value={secretToken} onChange={(e) => setSecretToken(e.target.value)} style={{ minWidth: 460 }} />
        </div>
        <div className="row" style={{ marginTop: 8 }}>
          <button type="button" onClick={() => void saveTgConfig()} disabled={busy}>{t.saveTg}</button>
        </div>
      </section>

      <section className="panel" style={{ marginBottom: 16 }}>
        <h3>{t.llmConfig}</h3>
        <div className="row">
          <label>{t.provider}</label>
          <select value={provider} onChange={(e) => setProvider(e.target.value)}>
            <option value="openai">OpenAI</option>
            <option value="anthropic">Anthropic</option>
            <option value="google">Google (Gemini)</option>
          </select>

          <label>{t.model}</label>
          <input type="text" value={model} onChange={(e) => setModel(e.target.value)} style={{ minWidth: 260 }} />
        </div>

        <div className="row" style={{ marginTop: 8 }}>
          <label>{t.apiKey}</label>
          <input type="password" value={apiKey} onChange={(e) => setApiKey(e.target.value)} style={{ minWidth: 460 }} />
        </div>

        <div style={{ marginTop: 8 }}>
          <label>{t.systemPrompt}</label>
          <textarea value={systemPrompt} onChange={(e) => setSystemPrompt(e.target.value)} />
        </div>

        <div className="row" style={{ marginTop: 8 }}>
          <label>
            <input type="checkbox" checked={includeHistory} onChange={(e) => setIncludeHistory(e.target.checked)} /> {t.includeHistory}
          </label>
          <button type="button" onClick={() => void saveLlmConfig()} disabled={busy}>{t.saveLlm}</button>
        </div>
      </section>

      <section className="panel">
        <h3>{t.webhook}</h3>
        <div className="row">
          <label>{t.webhookUrl}</label>
          <input type="text" value={webhookUrl} onChange={(e) => setWebhookUrl(e.target.value)} style={{ minWidth: 560 }} />
          <button type="button" onClick={() => void setWebhook()} disabled={busy}>{t.setWebhook}</button>
        </div>
      </section>

      <section className="panel" style={{ marginTop: 16 }}>
        <h3>{t.skills}</h3>
        <div className="row" style={{ marginBottom: 8 }}>
          <button type="button" onClick={() => void loadSkills()} disabled={busy}>
            {t.loadSkills}
          </button>
        </div>

        <div style={{ marginBottom: 8, fontWeight: 600 }}>{t.skillList}</div>
        <div className="row" style={{ marginBottom: 8 }}>
          {skills.length === 0 ? (
            <span>{t.noSkills}</span>
          ) : (
            skills.map((name) => (
              <button
                key={name}
                type="button"
                onClick={() => void loadSkillDetail(name)}
                disabled={busy}
                className={name === selectedSkill ? 'selectedSkill' : ''}
              >
                {name}
              </button>
            ))
          )}
        </div>

        <div style={{ marginBottom: 8, fontWeight: 600 }}>{t.skillDetail}</div>
        <textarea value={skillDetail} readOnly placeholder={selectedSkill || ''} />
      </section>
    </main>
  );
}
