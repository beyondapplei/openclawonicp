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
    saveApiKey: '保存 API Key 到后端（加密）',
    apiKeyStored: '后端已存储该 Provider 的 API Key',
    systemPrompt: 'System Prompt（可选）',
    includeHistory: '包含历史上下文',
    saveLlm: '保存默认 LLM',
    webhook: 'Webhook 配置',
    webhookUrl: 'Webhook URL',
    setWebhook: '设置 Webhook',
    discordConfig: 'Discord 配置',
    discordProxySecret: 'Proxy Secret（用于验签网关）',
    saveDiscord: '保存 Discord 配置',
    discordConfigured: '已配置 Discord',
    hasProxySecret: '已配置 Proxy Secret',
    ckethConfig: 'ckETH 报价源配置',
    icpswapQuoteUrl: 'ICPSwap Quote URL',
    kongswapQuoteUrl: 'KongSwap Quote URL',
    saveCkethSources: '保存报价源',
    hasIcpswapQuoteUrl: '已配置 ICPSwap 报价源',
    hasKongswapQuoteUrl: '已配置 KongSwap 报价源',
    hasIcpswapBroker: '已配置 ICPSwap Broker（可选）',
    hasKongswapBroker: '已配置 KongSwap Broker（可选）',
    skills: '后端技能',
    loadSkills: '加载后端技能',
    skillList: '技能列表',
    noSkills: '暂无技能',
    skillDetail: '技能详情',
    skillName: '技能名称',
    saveSkill: '保存技能',
    deleteSkill: '删除技能',
    needSkillName: '技能名称不能为空',
    hooks: '自动化 Hooks',
    loadHooks: '加载 Hooks',
    hookList: 'Hook 列表',
    noHooks: '暂无 Hooks',
    hookEditor: 'Hook 编辑',
    hookName: 'Hook 名称',
    triggerType: '触发类型',
    triggerValue: '触发值',
    actionType: '动作类型',
    actionReply: '回复内容',
    actionTool: '工具名称',
    actionToolArgs: '工具参数（每行一个）',
    hookEnabled: '已启用',
    triggerCommand: '命令触发',
    triggerMessage: '关键词触发',
    actionReplyLabel: '直接回复',
    actionToolLabel: '调用工具',
    saveHook: '保存 Hook',
    deleteHook: '删除 Hook',
    clearHookForm: '清空表单',
    needHookName: 'Hook 名称不能为空',
    needTriggerValue: '触发值不能为空',
    needActionReply: '回复内容不能为空',
    needActionTool: '工具名称不能为空',
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
    saveApiKey: 'Save API Key to backend (encrypted)',
    apiKeyStored: 'Backend has stored API key for this provider',
    systemPrompt: 'System Prompt (optional)',
    includeHistory: 'Include history context',
    saveLlm: 'Save default LLM',
    webhook: 'Webhook config',
    webhookUrl: 'Webhook URL',
    setWebhook: 'Set Webhook',
    discordConfig: 'Discord config',
    discordProxySecret: 'Proxy Secret (for signature gateway)',
    saveDiscord: 'Save Discord config',
    discordConfigured: 'Discord configured',
    hasProxySecret: 'Proxy secret configured',
    ckethConfig: 'ckETH quote sources',
    icpswapQuoteUrl: 'ICPSwap Quote URL',
    kongswapQuoteUrl: 'KongSwap Quote URL',
    saveCkethSources: 'Save quote sources',
    hasIcpswapQuoteUrl: 'ICPSwap quote source configured',
    hasKongswapQuoteUrl: 'KongSwap quote source configured',
    hasIcpswapBroker: 'ICPSwap broker configured (optional)',
    hasKongswapBroker: 'KongSwap broker configured (optional)',
    skills: 'Backend Skills',
    loadSkills: 'Load backend skills',
    skillList: 'Skill list',
    noSkills: 'No skills',
    skillDetail: 'Skill detail',
    skillName: 'Skill name',
    saveSkill: 'Save skill',
    deleteSkill: 'Delete skill',
    needSkillName: 'Skill name is required',
    hooks: 'Automation Hooks',
    loadHooks: 'Load Hooks',
    hookList: 'Hook list',
    noHooks: 'No hooks',
    hookEditor: 'Hook editor',
    hookName: 'Hook name',
    triggerType: 'Trigger type',
    triggerValue: 'Trigger value',
    actionType: 'Action type',
    actionReply: 'Reply text',
    actionTool: 'Tool name',
    actionToolArgs: 'Tool args (one per line)',
    hookEnabled: 'Enabled',
    triggerCommand: 'Command trigger',
    triggerMessage: 'Keyword trigger',
    actionReplyLabel: 'Reply text',
    actionToolLabel: 'Invoke tool',
    saveHook: 'Save Hook',
    deleteHook: 'Delete Hook',
    clearHookForm: 'Clear form',
    needHookName: 'Hook name is required',
    needTriggerValue: 'Trigger value is required',
    needActionReply: 'Reply text is required',
    needActionTool: 'Tool name is required',
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
  const [discordStatus, setDiscordStatus] = useState(null);
  const [ckethStatus, setCkethStatus] = useState(null);

  const [botToken, setBotToken] = useState('');
  const [secretToken, setSecretToken] = useState('');
  const [discordProxySecret, setDiscordProxySecret] = useState('');
  const [icpswapQuoteUrl, setIcpswapQuoteUrl] = useState('');
  const [kongswapQuoteUrl, setKongswapQuoteUrl] = useState('');

  const [provider, setProvider] = useState('google');
  const [model, setModel] = useState('gemini-1.5-flash');
  const [apiKey, setApiKey] = useState('');
  const [apiKeyStored, setApiKeyStored] = useState(false);
  const [systemPrompt, setSystemPrompt] = useState('');
  const [includeHistory, setIncludeHistory] = useState(true);

  const [webhookUrl, setWebhookUrl] = useState('');

  const [skills, setSkills] = useState([]);
  const [selectedSkill, setSelectedSkill] = useState('');
  const [skillName, setSkillName] = useState('');
  const [skillDetail, setSkillDetail] = useState('');

  const [hooks, setHooks] = useState([]);
  const [selectedHook, setSelectedHook] = useState('');
  const [hookName, setHookName] = useState('');
  const [hookTriggerType, setHookTriggerType] = useState('command');
  const [hookTriggerValue, setHookTriggerValue] = useState('');
  const [hookActionType, setHookActionType] = useState('reply');
  const [hookReply, setHookReply] = useState('');
  const [hookToolName, setHookToolName] = useState('');
  const [hookToolArgsText, setHookToolArgsText] = useState('');
  const [hookEnabled, setHookEnabled] = useState(true);

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

  useEffect(() => {
    let cancelled = false;
    async function loadStoredApiKeyFlag() {
      if (!actor || !isAuthed) return;
      try {
        const hasKey = await actor.admin_has_provider_api_key(providerVariant(provider));
        if (!cancelled) setApiKeyStored(Boolean(hasKey));
      } catch (_) {
        if (!cancelled) setApiKeyStored(false);
      }
    }
    void loadStoredApiKeyFlag();
    return () => {
      cancelled = true;
    };
  }, [actor, isAuthed, provider]);

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
      const ds = await actor.discord_status();
      const cs = await actor.cketh_status();
      setTgStatus(s);
      setDiscordStatus(ds);
      setCkethStatus(cs);
      const hasKey = await actor.admin_has_provider_api_key(providerVariant(provider));
      setApiKeyStored(Boolean(hasKey));
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
    if (!model.trim()) {
      setStatus(t.required);
      return;
    }
    setBusy(true);
    try {
      await actor.admin_set_llm_opts({
        provider: providerVariant(provider),
        model: model.trim(),
        apiKey: '',
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

  async function saveDiscordConfig() {
    if (!actor) return;
    setBusy(true);
    try {
      await actor.admin_set_discord(discordProxySecret.trim() ? [discordProxySecret.trim()] : []);
      setStatus(t.ok);
      await refreshStatus();
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
      setBusy(false);
    }
  }

  async function saveCkethQuoteSources() {
    if (!actor) return;
    setBusy(true);
    try {
      await actor.admin_set_cketh_quote_sources(
        icpswapQuoteUrl.trim() ? [icpswapQuoteUrl.trim()] : [],
        kongswapQuoteUrl.trim() ? [kongswapQuoteUrl.trim()] : [],
      );
      setStatus(t.ok);
      await refreshStatus();
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
      setBusy(false);
    }
  }

  async function saveProviderApiKey() {
    if (!actor) return;
    if (!apiKey.trim()) {
      setStatus(t.required);
      return;
    }
    setBusy(true);
    try {
      await actor.admin_set_provider_api_key(providerVariant(provider), apiKey.trim());
      setApiKeyStored(true);
      setApiKey('');
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
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
      setSelectedSkill((prev) => (prev && list.includes(prev) ? prev : ''));
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
      setSkillName(name);
      setSkillDetail(detail?.[0] ?? '');
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function saveSkill() {
    if (!actor) return;
    if (!skillName.trim()) {
      setStatus(t.needSkillName);
      return;
    }
    setBusy(true);
    try {
      await actor.skills_put(skillName.trim(), skillDetail);
      await loadSkills();
      await loadSkillDetail(skillName.trim());
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function deleteSkill() {
    if (!actor) return;
    if (!selectedSkill.trim()) {
      setStatus(t.needSkillName);
      return;
    }
    setBusy(true);
    try {
      await actor.skills_delete(selectedSkill);
      await loadSkills();
      setSelectedSkill('');
      setSkillName('');
      setSkillDetail('');
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  function parseHookToolArgs(text) {
    return text
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
  }

  function clearHookForm() {
    setSelectedHook('');
    setHookName('');
    setHookTriggerType('command');
    setHookTriggerValue('');
    setHookActionType('reply');
    setHookReply('');
    setHookToolName('');
    setHookToolArgsText('');
    setHookEnabled(true);
  }

  function fillHookForm(hook) {
    setSelectedHook(hook.name);
    setHookName(hook.name);
    setHookEnabled(Boolean(hook.enabled));
    if ('command' in hook.trigger) {
      setHookTriggerType('command');
      setHookTriggerValue(hook.trigger.command);
    } else {
      setHookTriggerType('messageContains');
      setHookTriggerValue(hook.trigger.messageContains);
    }

    if ('reply' in hook.action) {
      setHookActionType('reply');
      setHookReply(hook.action.reply);
      setHookToolName('');
      setHookToolArgsText('');
    } else {
      setHookActionType('tool');
      setHookReply('');
      setHookToolName(hook.action.tool.name);
      setHookToolArgsText((hook.action.tool.args || []).join('\n'));
    }
  }

  async function loadHooks() {
    if (!actor) return;
    setBusy(true);
    try {
      const list = await actor.hooks_list();
      setHooks(list);
      setSelectedHook((prev) => (prev && list.some((h) => h.name === prev) ? prev : ''));
      setStatus(t.ok);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function saveHook() {
    if (!actor) return;
    if (!hookName.trim()) {
      setStatus(t.needHookName);
      return;
    }
    if (!hookTriggerValue.trim()) {
      setStatus(t.needTriggerValue);
      return;
    }

    setBusy(true);
    try {
      let ok = false;
      if (hookActionType === 'reply') {
        if (!hookReply.trim()) {
          setStatus(t.needActionReply);
          setBusy(false);
          return;
        }
        if (hookTriggerType === 'command') {
          ok = await actor.hooks_put_command_reply(hookName.trim(), hookTriggerValue.trim(), hookReply);
        } else {
          ok = await actor.hooks_put_message_reply(hookName.trim(), hookTriggerValue.trim(), hookReply);
        }
      } else {
        if (!hookToolName.trim()) {
          setStatus(t.needActionTool);
          setBusy(false);
          return;
        }
        const toolArgs = parseHookToolArgs(hookToolArgsText);
        if (hookTriggerType === 'command') {
          ok = await actor.hooks_put_command_tool(hookName.trim(), hookTriggerValue.trim(), hookToolName.trim(), toolArgs);
        } else {
          ok = await actor.hooks_put_message_tool(hookName.trim(), hookTriggerValue.trim(), hookToolName.trim(), toolArgs);
        }
      }

      if (!ok) {
        setStatus(t.required);
      } else {
        await actor.hooks_set_enabled(hookName.trim(), hookEnabled);
        await loadHooks();
        setSelectedHook(hookName.trim());
        setStatus(t.ok);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function deleteHook() {
    if (!actor) return;
    if (!selectedHook.trim()) {
      setStatus(t.needHookName);
      return;
    }
    setBusy(true);
    try {
      await actor.hooks_delete(selectedHook.trim());
      await loadHooks();
      clearHookForm();
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
          {discordStatus && (
            <div style={{ marginTop: 8 }}>
              <div>{t.discordConfigured}: {String(discordStatus.configured)}</div>
              <div>{t.hasProxySecret}: {String(discordStatus.hasProxySecret)}</div>
              <div>{t.hasLlmConfig}: {String(discordStatus.hasLlmConfig)}</div>
            </div>
          )}
          {ckethStatus && (
            <div style={{ marginTop: 8 }}>
              <div>{t.hasIcpswapQuoteUrl}: {String(ckethStatus.hasIcpswapQuoteUrl)}</div>
              <div>{t.hasKongswapQuoteUrl}: {String(ckethStatus.hasKongswapQuoteUrl)}</div>
              <div>{t.hasIcpswapBroker}: {String(ckethStatus.hasIcpswapBroker)}</div>
              <div>{t.hasKongswapBroker}: {String(ckethStatus.hasKongswapBroker)}</div>
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
          <button type="button" onClick={() => void saveProviderApiKey()} disabled={busy}>{t.saveApiKey}</button>
        </div>
        <div className="status">{t.apiKeyStored}: {String(apiKeyStored)}</div>

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
        <h3>{t.discordConfig}</h3>
        <div className="row">
          <label>{t.discordProxySecret}</label>
          <input type="password" value={discordProxySecret} onChange={(e) => setDiscordProxySecret(e.target.value)} style={{ minWidth: 460 }} />
          <button type="button" onClick={() => void saveDiscordConfig()} disabled={busy}>{t.saveDiscord}</button>
        </div>
      </section>

      <section className="panel" style={{ marginTop: 16 }}>
        <h3>{t.ckethConfig}</h3>
        <div className="row" style={{ marginBottom: 8 }}>
          <label>{t.icpswapQuoteUrl}</label>
          <input type="text" value={icpswapQuoteUrl} onChange={(e) => setIcpswapQuoteUrl(e.target.value)} style={{ minWidth: 560 }} />
        </div>
        <div className="row" style={{ marginBottom: 8 }}>
          <label>{t.kongswapQuoteUrl}</label>
          <input type="text" value={kongswapQuoteUrl} onChange={(e) => setKongswapQuoteUrl(e.target.value)} style={{ minWidth: 560 }} />
        </div>
        <div className="row">
          <button type="button" onClick={() => void saveCkethQuoteSources()} disabled={busy}>{t.saveCkethSources}</button>
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
        <div className="row" style={{ marginBottom: 8 }}>
          <label>{t.skillName}</label>
          <input type="text" value={skillName} onChange={(e) => setSkillName(e.target.value)} style={{ minWidth: 300 }} />
          <button type="button" onClick={() => void saveSkill()} disabled={busy}>{t.saveSkill}</button>
          <button type="button" onClick={() => void deleteSkill()} disabled={busy || !selectedSkill}>{t.deleteSkill}</button>
        </div>
        <textarea value={skillDetail} onChange={(e) => setSkillDetail(e.target.value)} placeholder={selectedSkill || ''} />
      </section>

      <section className="panel" style={{ marginTop: 16 }}>
        <h3>{t.hooks}</h3>
        <div className="row" style={{ marginBottom: 8 }}>
          <button type="button" onClick={() => void loadHooks()} disabled={busy}>{t.loadHooks}</button>
          <button type="button" onClick={clearHookForm} disabled={busy}>{t.clearHookForm}</button>
        </div>

        <div style={{ marginBottom: 8, fontWeight: 600 }}>{t.hookList}</div>
        <div className="row" style={{ marginBottom: 10 }}>
          {hooks.length === 0 ? (
            <span>{t.noHooks}</span>
          ) : (
            hooks.map((hook) => (
              <button
                key={hook.name}
                type="button"
                onClick={() => fillHookForm(hook)}
                disabled={busy}
                className={hook.name === selectedHook ? 'selectedSkill' : ''}
              >
                {hook.enabled ? '✅ ' : '⏸️ '}{hook.name}
              </button>
            ))
          )}
        </div>

        <div style={{ marginBottom: 8, fontWeight: 600 }}>{t.hookEditor}</div>
        <div className="row" style={{ marginBottom: 8 }}>
          <label>{t.hookName}</label>
          <input type="text" value={hookName} onChange={(e) => setHookName(e.target.value)} style={{ minWidth: 220 }} />

          <label>{t.triggerType}</label>
          <select value={hookTriggerType} onChange={(e) => setHookTriggerType(e.target.value)}>
            <option value="command">{t.triggerCommand}</option>
            <option value="messageContains">{t.triggerMessage}</option>
          </select>

          <label>
            <input type="checkbox" checked={hookEnabled} onChange={(e) => setHookEnabled(e.target.checked)} /> {t.hookEnabled}
          </label>
        </div>

        <div className="row" style={{ marginBottom: 8 }}>
          <label>{t.triggerValue}</label>
          <input type="text" value={hookTriggerValue} onChange={(e) => setHookTriggerValue(e.target.value)} style={{ minWidth: 360 }} />

          <label>{t.actionType}</label>
          <select value={hookActionType} onChange={(e) => setHookActionType(e.target.value)}>
            <option value="reply">{t.actionReplyLabel}</option>
            <option value="tool">{t.actionToolLabel}</option>
          </select>
        </div>

        {hookActionType === 'reply' ? (
          <div style={{ marginBottom: 8 }}>
            <label>{t.actionReply}</label>
            <textarea value={hookReply} onChange={(e) => setHookReply(e.target.value)} />
          </div>
        ) : (
          <>
            <div className="row" style={{ marginBottom: 8 }}>
              <label>{t.actionTool}</label>
              <input type="text" value={hookToolName} onChange={(e) => setHookToolName(e.target.value)} style={{ minWidth: 320 }} />
            </div>
            <div style={{ marginBottom: 8 }}>
              <label>{t.actionToolArgs}</label>
              <textarea value={hookToolArgsText} onChange={(e) => setHookToolArgsText(e.target.value)} />
            </div>
          </>
        )}

        <div className="row" style={{ marginTop: 8 }}>
          <button type="button" onClick={() => void saveHook()} disabled={busy}>{t.saveHook}</button>
          <button type="button" onClick={() => void deleteHook()} disabled={busy || !selectedHook}>{t.deleteHook}</button>
        </div>
      </section>
    </main>
  );
}
