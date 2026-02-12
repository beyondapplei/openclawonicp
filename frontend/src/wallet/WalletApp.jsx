import React, { useEffect, useMemo, useState } from 'react';
import { computeAddress, parseEther } from 'ethers';
import { initAuth, loginWithII, logoutII } from '../auth';

const I18N = {
  zh: {
    title: '钱包',
    subtitle: 'OpenClaw Agent Wallet',
    back: '返回聊天页',
    lang: 'English',
    login: 'Identity 登录',
    logout: '退出登录',
    authLoading: '身份初始化中…',
    principal: 'Principal',
    icpRecv: 'ICP 接受地址',
    ethWallet: 'Agent ETH 钱包',
    balances: '资产',
    refreshBalances: '刷新余额',
    balIcp: 'ICP 余额(e8s)',
    balEth: 'ETH 余额(wei)',
    balIcrc1: 'ICRC1 余额',
    balErc20: 'ERC20 余额',
    toPrincipal: '目标 Principal',
    amountE8s: '金额 (e8s)',
    sendIcp: '发送 ICP',
    ethNet: 'ETH 网络',
    rpcUrl: 'RPC URL（可选）',
    ethTo: 'ETH 目标地址',
    ethAmount: 'ETH 数量',
    sendEth: '发送 ETH',
    icrc1Ledger: 'ICRC1 Ledger Principal',
    icrc1Amount: 'ICRC1 金额',
    icrc1Fee: 'ICRC1 Fee（可选）',
    sendIcrc1: '发送 ICRC1',
    erc20Token: 'ERC20 合约地址',
    erc20To: 'ERC20 目标地址',
    erc20Amount: 'ERC20 数量(最小单位)',
    sendErc20: '发送 ERC20',
    sending: '发送中…',
    done: '完成',
    errPrefix: '错误：',
    exPrefix: '异常：',
    needLedger: 'Ledger Principal 不能为空',
    needIcrc1Amount: 'ICRC1 金额必须大于 0',
    needErc20Token: 'ERC20 合约地址不能为空',
    needErc20To: 'ERC20 目标地址不能为空',
    needErc20Amount: 'ERC20 数量必须大于 0',
    needTo: '目标 Principal 不能为空',
    needAmount: '金额必须大于 0',
    needEthTo: 'ETH 目标地址不能为空',
    needEthAmount: 'ETH 数量必须大于 0',
    status: '状态',
  },
  en: {
    title: 'Wallet',
    subtitle: 'OpenClaw Agent Wallet',
    back: 'Back to chat',
    lang: '中文',
    login: 'Login with Identity',
    logout: 'Logout',
    authLoading: 'Initializing identity…',
    principal: 'Principal',
    icpRecv: 'ICP Receive Address',
    ethWallet: 'Agent ETH Wallet',
    balances: 'Assets',
    refreshBalances: 'Refresh balances',
    balIcp: 'ICP Balance (e8s)',
    balEth: 'ETH Balance (wei)',
    balIcrc1: 'ICRC1 Balance',
    balErc20: 'ERC20 Balance',
    toPrincipal: 'To Principal',
    amountE8s: 'Amount (e8s)',
    sendIcp: 'Send ICP',
    ethNet: 'ETH Network',
    rpcUrl: 'RPC URL (optional)',
    ethTo: 'ETH Destination',
    ethAmount: 'ETH Amount',
    sendEth: 'Send ETH',
    icrc1Ledger: 'ICRC1 Ledger Principal',
    icrc1Amount: 'ICRC1 Amount',
    icrc1Fee: 'ICRC1 Fee (optional)',
    sendIcrc1: 'Send ICRC1',
    erc20Token: 'ERC20 Token Address',
    erc20To: 'ERC20 Destination',
    erc20Amount: 'ERC20 Amount (base unit)',
    sendErc20: 'Send ERC20',
    sending: 'Sending…',
    done: 'Done',
    errPrefix: 'Error: ',
    exPrefix: 'Exception: ',
    needLedger: 'Ledger principal is required',
    needIcrc1Amount: 'ICRC1 amount must be greater than 0',
    needErc20Token: 'ERC20 token address is required',
    needErc20To: 'ERC20 destination is required',
    needErc20Amount: 'ERC20 amount must be greater than 0',
    needTo: 'Destination principal is required',
    needAmount: 'Amount must be greater than 0',
    needEthTo: 'ETH destination is required',
    needEthAmount: 'ETH amount must be greater than 0',
    status: 'Status',
  },
};

export default function WalletApp() {
  const [lang, setLang] = useState('zh');
  const t = useMemo(() => I18N[lang] ?? I18N.zh, [lang]);

  const [authClient, setAuthClient] = useState(null);
  const [actor, setActor] = useState(null);
  const [isAuthed, setIsAuthed] = useState(false);
  const [principalText, setPrincipalText] = useState('');
  const [canisterPrincipalText, setCanisterPrincipalText] = useState('');
  const [ethWallet, setEthWallet] = useState('');
  const [authLoading, setAuthLoading] = useState(true);

  const [sendToPrincipal, setSendToPrincipal] = useState('');
  const [sendAmountE8s, setSendAmountE8s] = useState('');
  const [ethNetwork, setEthNetwork] = useState('ethereum');
  const [ethRpcUrl, setEthRpcUrl] = useState('');
  const [ethTo, setEthTo] = useState('');
  const [ethAmount, setEthAmount] = useState('');
  const [erc20TokenAddress, setErc20TokenAddress] = useState('');
  const [erc20To, setErc20To] = useState('');
  const [erc20Amount, setErc20Amount] = useState('');
  const [icrc1LedgerPrincipal, setIcrc1LedgerPrincipal] = useState('');
  const [icrc1Amount, setIcrc1Amount] = useState('');
  const [icrc1Fee, setIcrc1Fee] = useState('');
  const [balIcp, setBalIcp] = useState('-');
  const [balEth, setBalEth] = useState('-');
  const [balIcrc1, setBalIcrc1] = useState('-');
  const [balErc20, setBalErc20] = useState('-');

  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    document.body.classList.add('walletFullscreenBody');
    return () => {
      document.body.classList.remove('walletFullscreenBody');
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function bootstrap() {
      setAuthLoading(true);
      try {
        const auth = await initAuth();
        if (cancelled) return;
        setAuthClient(auth.client);
        setActor(auth.actor);
        setIsAuthed(auth.isAuthenticated);
        setPrincipalText(auth.principalText || '');
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
    void refreshWallet(actor);
    void refreshBalances(actor);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [actor, isAuthed, authClient]);

  async function login() {
    if (!authClient) return;
    setBusy(true);
    try {
      const r = await loginWithII(authClient);
      setActor(r.actor);
      setIsAuthed(true);
      setPrincipalText(r.principalText);
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
      setCanisterPrincipalText('');
      setEthWallet('');
      setBalIcp('-');
      setBalEth('-');
      setBalIcrc1('-');
      setBalErc20('-');
      setStatus(t.done);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function refreshWallet(a = actor) {
    if (!a || !isAuthed) {
      setEthWallet('');
      setCanisterPrincipalText('');
      return;
    }
    try {
      const p = await a.canister_principal();
      setCanisterPrincipalText(String(p));

      const res = await a.agent_wallet();
      if ('ok' in res) {
        const pubHex = `0x${res.ok.publicKeyHex}`;
        const addr = computeAddress(pubHex);
        setEthWallet(addr);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    }
  }

  async function refreshBalances(a = actor) {
    if (!a || !isAuthed) {
      setBalIcp('-');
      setBalEth('-');
      setBalIcrc1('-');
      setBalErc20('-');
      return;
    }

    setBusy(true);
    try {
      const icpRes = await a.wallet_balance_icp();
      if ('ok' in icpRes) setBalIcp(icpRes.ok.toString());

      const ethRes = await a.wallet_balance_eth(ethNetwork, ethRpcUrl.trim() ? [ethRpcUrl.trim()] : []);
      if ('ok' in ethRes) setBalEth(ethRes.ok.toString());

      if (icrc1LedgerPrincipal.trim()) {
        const icrc1Res = await a.wallet_balance_icrc1(icrc1LedgerPrincipal.trim());
        if ('ok' in icrc1Res) {
          setBalIcrc1(icrc1Res.ok.toString());
        } else {
          setBalIcrc1('-');
        }
      } else {
        setBalIcrc1('-');
      }

      if (erc20TokenAddress.trim()) {
        const erc20Res = await a.wallet_balance_erc20(
          ethNetwork,
          ethRpcUrl.trim() ? [ethRpcUrl.trim()] : [],
          erc20TokenAddress.trim(),
        );
        if ('ok' in erc20Res) {
          setBalErc20(erc20Res.ok.toString());
        } else {
          setBalErc20('-');
        }
      } else {
        setBalErc20('-');
      }

      setStatus(t.done);
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function sendIcp() {
    if (!actor) return;
    if (!sendToPrincipal.trim()) return setStatus(t.needTo);

    let amount = 0n;
    try {
      amount = BigInt(sendAmountE8s.trim() || '0');
    } catch (_) {
      setStatus(t.needAmount);
      return;
    }
    if (amount <= 0n) return setStatus(t.needAmount);

    setBusy(true);
    setStatus(t.sending);
    try {
      const res = await actor.wallet_send_icp(sendToPrincipal.trim(), amount);
      if ('ok' in res) {
        setStatus(`${t.done} #${res.ok.toString()}`);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function sendEth() {
    if (!actor) return;
    if (!ethTo.trim()) return setStatus(t.needEthTo);
    if (!ethAmount.trim()) return setStatus(t.needEthAmount);

    let valueWei = 0n;
    try {
      valueWei = parseEther(ethAmount.trim());
    } catch (_) {
      setStatus(t.needEthAmount);
      return;
    }
    if (valueWei <= 0n) return setStatus(t.needEthAmount);

    setBusy(true);
    setStatus(t.sending);
    try {
      const sendRes = await actor.wallet_send_eth(
        ethNetwork,
        ethRpcUrl.trim() ? [ethRpcUrl.trim()] : [],
        ethTo.trim(),
        valueWei,
      );
      if ('ok' in sendRes) {
        setStatus(`${t.done} tx: ${sendRes.ok}`);
      } else {
        setStatus(`${t.errPrefix}${sendRes.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function sendIcrc1() {
    if (!actor) return;
    if (!icrc1LedgerPrincipal.trim()) return setStatus(t.needLedger);

    let amount = 0n;
    try {
      amount = BigInt(icrc1Amount.trim() || '0');
    } catch (_) {
      setStatus(t.needIcrc1Amount);
      return;
    }
    if (amount <= 0n) return setStatus(t.needIcrc1Amount);

    let feeOpt = [];
    if (icrc1Fee.trim()) {
      try {
        feeOpt = [BigInt(icrc1Fee.trim())];
      } catch (_) {
        setStatus(t.needIcrc1Amount);
        return;
      }
    }

    setBusy(true);
    setStatus(t.sending);
    try {
      const res = await actor.wallet_send_icrc1(
        icrc1LedgerPrincipal.trim(),
        canisterPrincipalText || principalText,
        amount,
        feeOpt,
      );
      if ('ok' in res) {
        setStatus(`${t.done} #${res.ok.toString()}`);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function sendErc20() {
    if (!actor) return;
    if (!erc20TokenAddress.trim()) return setStatus(t.needErc20Token);
    if (!erc20To.trim()) return setStatus(t.needErc20To);

    let amount = 0n;
    try {
      amount = BigInt(erc20Amount.trim() || '0');
    } catch (_) {
      setStatus(t.needErc20Amount);
      return;
    }
    if (amount <= 0n) return setStatus(t.needErc20Amount);

    setBusy(true);
    setStatus(t.sending);
    try {
      const res = await actor.wallet_send_erc20(
        ethNetwork,
        ethRpcUrl.trim() ? [ethRpcUrl.trim()] : [],
        erc20TokenAddress.trim(),
        erc20To.trim(),
        amount,
      );
      if ('ok' in res) {
        setStatus(`${t.done} tx: ${res.ok}`);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="walletPage">
      <header className="walletHeader">
        <div>
          <h1>{t.title}</h1>
          <p>{t.subtitle}</p>
        </div>
        <div className="walletHeaderActions">
          {!authLoading && (
            isAuthed ? (
              <button type="button" onClick={() => void logout()}>{t.logout}</button>
            ) : (
              <button type="button" onClick={() => void login()}>{t.login}</button>
            )
          )}
          <button type="button" onClick={() => (window.location.href = './')}>{t.back}</button>
          <button type="button" onClick={() => setLang((v) => (v === 'zh' ? 'en' : 'zh'))}>{t.lang}</button>
        </div>
      </header>

      <div className="walletLayout">
        <aside className="walletSidebar panel">
          {authLoading ? (
            <div className="status">{t.authLoading}</div>
          ) : (
            <>
              <div className="walletField"><span>{t.principal}</span><strong>{principalText || 'anonymous'}</strong></div>
              <div className="walletField"><span>{t.icpRecv}</span><strong>{canisterPrincipalText || '-'}</strong></div>
              <div className="walletField"><span>{t.ethWallet}</span><strong>{ethWallet || '-'}</strong></div>
            </>
          )}
          <div className="walletBalanceHeader">
            <h3>{t.balances}</h3>
            <button type="button" onClick={() => void refreshBalances()} disabled={busy || !isAuthed}>{t.refreshBalances}</button>
          </div>
          <div className="walletBalances">
            <div><span>{t.balIcp}</span><strong>{balIcp}</strong></div>
            <div><span>{t.balEth}</span><strong>{balEth}</strong></div>
            <div><span>{t.balIcrc1}</span><strong>{balIcrc1}</strong></div>
            <div><span>{t.balErc20}</span><strong>{balErc20}</strong></div>
          </div>
        </aside>

        <section className="walletMain">
          <div className="walletCard panel">
            <h3>{t.sendIcp}</h3>
            <div className="walletGrid2">
              <input
                type="text"
                placeholder={t.toPrincipal}
                value={sendToPrincipal}
                onChange={(e) => setSendToPrincipal(e.target.value)}
              />
              <input
                type="text"
                placeholder={t.amountE8s}
                value={sendAmountE8s}
                onChange={(e) => setSendAmountE8s(e.target.value)}
              />
            </div>
            <button type="button" onClick={() => void sendIcp()} disabled={busy || !isAuthed}>{t.sendIcp}</button>
          </div>

          <div className="walletCard panel">
            <h3>{t.sendEth}</h3>
            <div className="walletGrid3">
              <select value={ethNetwork} onChange={(e) => setEthNetwork(e.target.value)}>
                <option value="ethereum">Ethereum Mainnet</option>
                <option value="base">Base Mainnet</option>
              </select>
              <input
                type="text"
                placeholder={t.rpcUrl}
                value={ethRpcUrl}
                onChange={(e) => setEthRpcUrl(e.target.value)}
              />
              <input
                type="text"
                placeholder={t.ethTo}
                value={ethTo}
                onChange={(e) => setEthTo(e.target.value)}
              />
            </div>
            <div className="walletActionRow">
              <input
                type="text"
                placeholder={t.ethAmount}
                value={ethAmount}
                onChange={(e) => setEthAmount(e.target.value)}
              />
              <button type="button" onClick={() => void sendEth()} disabled={busy || !isAuthed}>{t.sendEth}</button>
            </div>
          </div>

          <div className="walletCard panel">
            <h3>{t.sendIcrc1}</h3>
            <div className="walletGrid3">
              <input
                type="text"
                placeholder={t.icrc1Ledger}
                value={icrc1LedgerPrincipal}
                onChange={(e) => setIcrc1LedgerPrincipal(e.target.value)}
              />
              <input
                type="text"
                placeholder={t.icrc1Amount}
                value={icrc1Amount}
                onChange={(e) => setIcrc1Amount(e.target.value)}
              />
              <input
                type="text"
                placeholder={t.icrc1Fee}
                value={icrc1Fee}
                onChange={(e) => setIcrc1Fee(e.target.value)}
              />
            </div>
            <button type="button" onClick={() => void sendIcrc1()} disabled={busy || !isAuthed}>{t.sendIcrc1}</button>
          </div>

          <div className="walletCard panel">
            <h3>{t.sendErc20}</h3>
            <div className="walletGrid3">
              <input
                type="text"
                placeholder={t.erc20Token}
                value={erc20TokenAddress}
                onChange={(e) => setErc20TokenAddress(e.target.value)}
              />
              <input
                type="text"
                placeholder={t.erc20To}
                value={erc20To}
                onChange={(e) => setErc20To(e.target.value)}
              />
              <input
                type="text"
                placeholder={t.erc20Amount}
                value={erc20Amount}
                onChange={(e) => setErc20Amount(e.target.value)}
              />
            </div>
            <button type="button" onClick={() => void sendErc20()} disabled={busy || !isAuthed}>{t.sendErc20}</button>
          </div>
        </section>
      </div>

      <footer className="walletFooter panel">
        <span>{t.status}</span>
        <strong>{status || '-'}</strong>
      </footer>
    </div>
  );
}
