import React, { useEffect, useMemo, useRef, useState } from 'react';
import { parseEther } from 'ethers';
import { initAuth } from '../auth';

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
    icpRecv: 'Agent ICP 接收地址',
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
    notOwnerLogin: '你不是管理员，无权登录',
    network: '网络',
    tokenTab: '代币',
    nftTab: 'NFT',
    totalBalance: '总资产',
    receive: '接收',
    send: '发送',
    swap: '兑换',
    buy: '购买',
    copied: '地址已复制',
    noAddress: '当前网络暂无可用地址',
    receiveAddressTitle: '接收地址',
    receiveAddressHint: '请将下面地址提供给转账方',
    sendPageTitle: '发送',
    sendToLabel: '收款地址',
    sendAmountLabel: '数量',
    sendAmountHintIcp: '输入 ICP 数量（支持小数）',
    sendAmountHintEth: '输入 ETH 数量（支持小数）',
    sendAmountHintIcrc1: '输入代币数量（支持小数）',
    sendAmountHintBase: '输入最小单位数量',
    sendConfirm: '确认发送',
    close: '关闭',
    sendNeedTo: '请填写收款地址',
    sendNeedAmount: '请填写正确数量',
    sendUnsupported: '当前币种暂不支持发送',
    sendMissingLedger: '缺少 ICRC1 账本 ID',
    sendMissingToken: '缺少 ERC20 合约地址',
    sendSuccess: '发送成功',
    backTokenList: '返回币种列表',
    transactionHistory: '交易记录',
    noHistory: '暂无交易记录',
    txFrom: '来自',
    txTo: '发送至',
    txHashLabel: '哈希',
    usdValuePlaceholder: 'US$ --',
    onChainBalance: '链上余额',
    actionNotReady: '功能开发中',
    receiveSheetTitle: '接收',
    receiveModalDone: '完成',
    receiveIcpOnly: 'ICP 钱包地址 - 仅限 ICP 代币',
    receiveIcrc: 'ICP 钱包地址 - ckBTC、CHAT 等',
    receiveEvm: '钱包地址',
    copy: '复制',
    qrCode: '二维码',
    qrNotReady: '二维码功能开发中',
    networkIc: 'Internet Computer',
    networkEth: 'Ethereum',
    networkSepolia: 'Sepolia',
    networkBase: 'Base',
    networkPolygon: 'Polygon',
    networkArbitrum: 'Arbitrum',
    networkOptimism: 'Optimism',
    networkBsc: 'BNB Chain',
    networkAvalanche: 'Avalanche C-Chain',
    networkSolana: 'Solana',
    tokenIcpName: 'Internet Computer',
    tokenIcrc1Name: 'ICRC1 Token',
    tokenEthName: 'Ethereum',
    tokenErc20Name: 'ERC20 Token',
    tokenSolName: 'Solana',
    addIcrc1Title: '添加 ICRC1 代币',
    addIcrc1Placeholder: '输入 ICRC1 Ledger Principal',
    addIcrc1Btn: '添加',
    addIcrc1Done: '已添加代币',
    addEvmTokenTitle: '添加 EVM 代币合约',
    addEvmTokenPlaceholder: '输入 ERC20 合约地址(0x...)',
    addEvmTokenSymbolPlaceholder: '代币符号(可选)',
    addEvmTokenBtn: '添加合约',
    addEvmTokenDone: '已添加 EVM 代币',
    needEvmTokenAddress: 'EVM 合约地址不能为空',
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
    notOwnerLogin: 'Not the agent owner. Login denied.',
    network: 'Network',
    tokenTab: 'Token',
    nftTab: 'NFT',
    totalBalance: 'Total Balance',
    receive: 'Receive',
    send: 'Send',
    swap: 'Swap',
    buy: 'Buy',
    copied: 'Address copied',
    noAddress: 'No available address on this network',
    receiveAddressTitle: 'Receive Address',
    receiveAddressHint: 'Share this address with the sender',
    sendPageTitle: 'Send',
    sendToLabel: 'To Address',
    sendAmountLabel: 'Amount',
    sendAmountHintIcp: 'Enter ICP amount (decimals allowed)',
    sendAmountHintEth: 'Enter ETH amount (decimals allowed)',
    sendAmountHintIcrc1: 'Enter token amount (decimals allowed)',
    sendAmountHintBase: 'Enter base-unit amount',
    sendConfirm: 'Send Now',
    close: 'Close',
    sendNeedTo: 'Destination address is required',
    sendNeedAmount: 'Amount is invalid',
    sendUnsupported: 'Sending is not supported for this asset',
    sendMissingLedger: 'Missing ICRC1 ledger principal',
    sendMissingToken: 'Missing ERC20 token address',
    sendSuccess: 'Sent',
    backTokenList: 'Back to tokens',
    transactionHistory: 'Transaction History',
    noHistory: 'No history',
    txFrom: 'From',
    txTo: 'To',
    txHashLabel: 'Hash',
    usdValuePlaceholder: 'US$ --',
    onChainBalance: 'On-chain balance',
    actionNotReady: 'Feature coming soon',
    receiveSheetTitle: 'Receive',
    receiveModalDone: 'Done',
    receiveIcpOnly: 'ICP wallet address - ICP only',
    receiveIcrc: 'ICP wallet address - ckBTC, CHAT',
    receiveEvm: 'Wallet address',
    copy: 'Copy',
    qrCode: 'QR',
    qrNotReady: 'QR feature coming soon',
    networkIc: 'Internet Computer',
    networkEth: 'Ethereum',
    networkSepolia: 'Sepolia',
    networkBase: 'Base',
    networkPolygon: 'Polygon',
    networkArbitrum: 'Arbitrum',
    networkOptimism: 'Optimism',
    networkBsc: 'BNB Chain',
    networkAvalanche: 'Avalanche C-Chain',
    networkSolana: 'Solana',
    tokenIcpName: 'Internet Computer',
    tokenIcrc1Name: 'ICRC1 Token',
    tokenEthName: 'Ethereum',
    tokenErc20Name: 'ERC20 Token',
    tokenSolName: 'Solana',
    addIcrc1Title: 'Add ICRC1 Token',
    addIcrc1Placeholder: 'Enter ICRC1 ledger principal',
    addIcrc1Btn: 'Add',
    addIcrc1Done: 'Token added',
    addEvmTokenTitle: 'Add EVM Token Contract',
    addEvmTokenPlaceholder: 'Enter ERC20 contract address (0x...)',
    addEvmTokenSymbolPlaceholder: 'Token symbol (optional)',
    addEvmTokenBtn: 'Add Contract',
    addEvmTokenDone: 'EVM token added',
    needEvmTokenAddress: 'EVM contract address is required',
  },
};

export default function WalletApp() {
  const overviewRequestSeqRef = useRef(0);

  const [lang, setLang] = useState('zh');
  const t = useMemo(() => I18N[lang] ?? I18N.zh, [lang]);

  const [actor, setActor] = useState(null);
  const [principalText, setPrincipalText] = useState('');
  const [canisterPrincipalText, setCanisterPrincipalText] = useState('');
  const [ethWallet, setEthWallet] = useState('');
  const [ownerPrincipalText, setOwnerPrincipalText] = useState('');
  const [viewNetwork, setViewNetwork] = useState('internet_computer');
  const [selectedTokenSymbol, setSelectedTokenSymbol] = useState('');
  const [selectedTokenDetail, setSelectedTokenDetail] = useState(null);
  const [selectedTokenHistoryRaw, setSelectedTokenHistoryRaw] = useState([]);
  const [sendPageOpen, setSendPageOpen] = useState(false);
  const [sendPageTo, setSendPageTo] = useState('');
  const [sendPageAmount, setSendPageAmount] = useState('');
  const [receiveModalOpen, setReceiveModalOpen] = useState(false);

  const [sendToPrincipal, setSendToPrincipal] = useState('');
  const [sendAmountE8s, setSendAmountE8s] = useState('');
  const [ethNetwork, setEthNetwork] = useState('ethereum');
  const [ethRpcUrl, setEthRpcUrl] = useState('');
  const [ethTo, setEthTo] = useState('');
  const [ethAmount, setEthAmount] = useState('');
  const [erc20TokenAddress, setErc20TokenAddress] = useState('');
  const [erc20To, setErc20To] = useState('');
  const [erc20Amount, setErc20Amount] = useState('');
  const [icrc1AddLedger, setIcrc1AddLedger] = useState('');
  const [evmAddTokenAddress, setEvmAddTokenAddress] = useState('');
  const [evmAddTokenSymbol, setEvmAddTokenSymbol] = useState('');
  const [icrc1LedgerPrincipal, setIcrc1LedgerPrincipal] = useState('');
  const [icrc1Amount, setIcrc1Amount] = useState('');
  const [icrc1Fee, setIcrc1Fee] = useState('');
  const [balIcp, setBalIcp] = useState('-');
  const [balEth, setBalEth] = useState('-');
  const [balIcrc1, setBalIcrc1] = useState('-');
  const [balErc20, setBalErc20] = useState('-');
  const [overviewBalances, setOverviewBalances] = useState([]);

  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);

  function isEvmNetwork(network) {
    return [
      'ethereum',
      'sepolia',
      'base',
      'polygon',
      'arbitrum',
      'optimism',
      'bsc',
      'avalanche',
    ].includes(network);
  }

  function principalToText(p) {
    if (!p) return '';
    if (typeof p.toText === 'function') return p.toText();
    return String(p);
  }

  function formatBaseUnits(raw, decimals, maxFractionDigits = 8) {
    if (!raw || raw === '-') return '--';
    try {
      const value = BigInt(raw);
      const base = 10n ** BigInt(decimals);
      const integer = value / base;
      const fraction = value % base;
      if (fraction === 0n) return integer.toString();
      const padded = fraction.toString().padStart(decimals, '0');
      const trimmed = padded.slice(0, maxFractionDigits).replace(/0+$/, '');
      return trimmed ? `${integer.toString()}.${trimmed}` : integer.toString();
    } catch (_) {
      return raw;
    }
  }

  function formatTokenBalance(symbol, raw, decimals = null) {
    if (!raw || raw === '-') return '0';
    if (typeof decimals === 'number' && Number.isFinite(decimals) && decimals >= 0) {
      return formatBaseUnits(raw, decimals, 8);
    }
    if (symbol === 'ICP') return formatBaseUnits(raw, 8, 8);
    if (symbol === 'ETH') return formatBaseUnits(raw, 18, 8);
    return raw;
  }

  function parseDecimalAmountToBaseUnits(rawAmount, decimals) {
    const trimmed = String(rawAmount ?? '').trim();
    if (!trimmed) return null;
    if (!/^\d+(\.\d+)?$/.test(trimmed)) return null;
    const [intPart, fracPartRaw = ''] = trimmed.split('.');
    if (fracPartRaw.length > decimals) return null;
    const fracPart = fracPartRaw.padEnd(decimals, '0');
    const base = 10n ** BigInt(decimals);
    return BigInt(intPart) * base + BigInt(fracPart || '0');
  }

  function toOptText(value) {
    const text = String(value ?? '').trim();
    return text ? [text] : [];
  }

  function fromOptText(value) {
    if (!Array.isArray(value) || value.length === 0) return '';
    return String(value[0] ?? '');
  }

  function receiveTitleByKind(kind, symbol) {
    if (kind === 'icp_only') return t.receiveIcpOnly;
    if (kind === 'icrc') return t.receiveIcrc;
    if (kind === 'solana') return `${symbol} ${t.receiveEvm}`;
    return `${symbol} ${t.receiveEvm}`;
  }

  function resolveReceiveAddresses(network, symbol, assetAddress, canisterAddress) {
    const symbolUpper = String(symbol ?? '').trim().toUpperCase();
    if (network === 'internet_computer') {
      if (symbolUpper === 'ICP') {
        return [
          { kind: 'icp_only', address: canisterAddress },
          { kind: 'icrc', address: canisterAddress },
        ];
      }
      return [{ kind: 'icrc', address: canisterAddress }];
    }
    if (network === 'solana') {
      return [{ kind: 'solana', address: assetAddress }];
    }
    return [{ kind: 'evm', address: assetAddress }];
  }

  function shortAddress(value) {
    const text = String(value ?? '').trim();
    if (!text) return '-';
    if (text.length <= 16) return text;
    return `${text.slice(0, 8)}...${text.slice(-8)}`;
  }

  function formatHistoryDateLabel(date) {
    if (lang === 'zh') return `${date.getMonth() + 1}月${date.getDate()}日`;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  function formatHistoryTime(date) {
    return date.toLocaleTimeString(lang === 'zh' ? 'zh-CN' : 'en-US', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });
  }

  async function refreshOwnerAccess(a) {
    if (!a) {
      setOwnerPrincipalText('');
      return;
    }
    try {
      const me = await a.canister_principal();
      setOwnerPrincipalText(principalToText(me));
    } catch (_) {
      setOwnerPrincipalText('');
    }
  }

  useEffect(() => {
    document.body.classList.add('walletFullscreenBody');
    return () => {
      document.body.classList.remove('walletFullscreenBody');
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function bootstrap() {
      const auth = await initAuth();
      if (cancelled) return;
      setActor(auth.actor);
      setPrincipalText('');
      await refreshOwnerAccess(auth.actor);
    }
    void bootstrap();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!actor) return;
    void refreshOverview(actor);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [actor, viewNetwork]);

  useEffect(() => {
    if (!selectedTokenSymbol) {
      setSelectedTokenDetail(null);
      return;
    }
    const wanted = String(selectedTokenSymbol).toUpperCase();
    const found = Array.isArray(overviewBalances)
      ? overviewBalances.find((item) => String(item?.symbol ?? '').toUpperCase() === wanted)
      : null;
    if (!found) {
      setSelectedTokenDetail(null);
      return;
    }
    const networkText = String(found.network ?? viewNetwork);
    const addressText = String(
      found.address
      ?? (
        networkText === 'internet_computer'
          ? canisterPrincipalText
          : (networkText === 'solana' ? '' : ethWallet)
      ),
    );
    setSelectedTokenDetail({
      ...found,
      address: addressText,
      receiveAddresses: resolveReceiveAddresses(networkText, found.symbol, addressText, canisterPrincipalText),
    });
  }, [selectedTokenSymbol, overviewBalances, viewNetwork, canisterPrincipalText, ethWallet]);

  useEffect(() => {
    if (!selectedTokenSymbol || !actor) {
      setSelectedTokenHistoryRaw([]);
      return;
    }
    const selectedSymbolUpper = String(selectedTokenSymbol).toUpperCase();
    const isIcpHistory = viewNetwork === 'internet_computer' && selectedSymbolUpper === 'ICP';
    const isEvmEthHistory = viewNetwork !== 'internet_computer' && viewNetwork !== 'solana' && selectedSymbolUpper === 'ETH';
    if (!isIcpHistory && !isEvmEthHistory) {
      setSelectedTokenHistoryRaw([]);
      return;
    }
    let cancelled = false;
    async function loadAssetHistory() {
      try {
        const res = await actor.wallet_asset_history(viewNetwork, selectedTokenSymbol, 50n);
        if (cancelled) return;
        if ('ok' in res) {
          setSelectedTokenHistoryRaw(Array.isArray(res.ok) ? res.ok : []);
        } else {
          setSelectedTokenHistoryRaw([]);
          setStatus(`${t.errPrefix}${res.err}`);
        }
      } catch (e) {
        if (!cancelled) {
          setSelectedTokenHistoryRaw([]);
          setStatus(`${t.exPrefix}${String(e)}`);
        }
      }
    }
    void loadAssetHistory();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedTokenSymbol, actor, viewNetwork]);

  async function refreshOverview(a = actor, network = viewNetwork) {
    if (!a) {
      setEthWallet('');
      setCanisterPrincipalText('');
      setBalIcp('-');
      setBalEth('-');
      setBalIcrc1('-');
      setBalErc20('-');
      setOverviewBalances([]);
      return;
    }

    const reqSeq = overviewRequestSeqRef.current + 1;
    overviewRequestSeqRef.current = reqSeq;

    setBusy(true);
    try {
      const overviewRes = await a.wallet_overview(
        network,
        toOptText(ethRpcUrl),
        toOptText(erc20TokenAddress),
      );
      if (reqSeq !== overviewRequestSeqRef.current) {
        return;
      }
      if (!('ok' in overviewRes)) {
        setBalIcp('-');
        setBalEth('-');
        setBalIcrc1('-');
        setBalErc20('-');
        setOverviewBalances([]);
        setStatus(`${t.errPrefix}${overviewRes.err}`);
        return;
      }

      const out = overviewRes.ok;
      const balances = Array.isArray(out.balances) ? out.balances : [];
      const findBySymbol = (symbol) => balances.find((item) => String(item.symbol).toUpperCase() === symbol);
      const renderBalance = (item) => (item && item.available ? item.amount.toString() : '-');
      const firstError = balances
        .map((item) => fromOptText(item.error))
        .find((value) => value.trim().length > 0);

      setCanisterPrincipalText(String(out.canisterPrincipalText ?? ''));
      setEthWallet(fromOptText(out.evmAddress));
      setOverviewBalances(balances);
      setBalIcp(renderBalance(findBySymbol('ICP')));
      setBalEth(renderBalance(findBySymbol('ETH')));
      setBalIcrc1(renderBalance(findBySymbol('ICRC1')));
      setBalErc20(renderBalance(findBySymbol('ERC20')));
      if (firstError) {
        setStatus(`${t.errPrefix}${firstError}`);
      } else {
        setStatus(t.done);
      }
    } catch (e) {
      if (reqSeq !== overviewRequestSeqRef.current) {
        return;
      }
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      if (reqSeq === overviewRequestSeqRef.current) {
        setBusy(false);
      }
    }
  }

  async function refreshWallet(a = actor) {
    await refreshOverview(a);
  }

  async function refreshBalances(a = actor) {
    await refreshOverview(a);
  }

  async function addIcrc1Token() {
    if (!actor) return;
    const ledger = icrc1AddLedger.trim();
    if (!ledger) {
      setStatus(t.needLedger);
      return;
    }
    setBusy(true);
    try {
      const res = await actor.wallet_icrc1_token_add(ledger);
      if ('ok' in res) {
        setIcrc1AddLedger('');
        setStatus(`${t.addIcrc1Done}: ${res.ok.symbol}`);
        await refreshOverview(actor);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function addEvmToken() {
    if (!actor) return;
    const address = evmAddTokenAddress.trim();
    const symbol = evmAddTokenSymbol.trim();
    if (!address) {
      setStatus(t.needEvmTokenAddress);
      return;
    }
    if (!isEvmNetwork(viewNetwork)) {
      setStatus(t.sendUnsupported);
      return;
    }
    setBusy(true);
    try {
      const res = await actor.wallet_evm_token_add(
        viewNetwork,
        address,
        symbol ? [symbol] : [],
        [],
        [],
      );
      if ('ok' in res) {
        setEvmAddTokenAddress('');
        setEvmAddTokenSymbol('');
        setStatus(`${t.addEvmTokenDone}: ${res.ok.symbol}`);
        await refreshOverview(actor);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
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
      const res = await actor.wallet_send({
        kind: { icp: null },
        network: [],
        rpcUrl: [],
        to: sendToPrincipal.trim(),
        amount,
        tokenAddress: [],
        ledgerPrincipalText: [],
        fee: [],
      });
      if ('ok' in res) {
        setStatus(`${t.done} #${res.ok.txId}`);
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
      const sendRes = await actor.wallet_send({
        kind: { eth: null },
        network: [ethNetwork],
        rpcUrl: toOptText(ethRpcUrl),
        to: ethTo.trim(),
        amount: valueWei,
        tokenAddress: [],
        ledgerPrincipalText: [],
        fee: [],
      });
      if ('ok' in sendRes) {
        setStatus(`${t.done} tx: ${sendRes.ok.txId}`);
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
      const res = await actor.wallet_send({
        kind: { icrc1: null },
        network: [],
        rpcUrl: [],
        to: canisterPrincipalText || principalText,
        amount,
        tokenAddress: [],
        ledgerPrincipalText: [icrc1LedgerPrincipal.trim()],
        fee: feeOpt,
      });
      if ('ok' in res) {
        setStatus(`${t.done} #${res.ok.txId}`);
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
      const res = await actor.wallet_send({
        kind: { erc20: null },
        network: [ethNetwork],
        rpcUrl: toOptText(ethRpcUrl),
        to: erc20To.trim(),
        amount,
        tokenAddress: [erc20TokenAddress.trim()],
        ledgerPrincipalText: [],
        fee: [],
      });
      if ('ok' in res) {
        setStatus(`${t.done} tx: ${res.ok.txId}`);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  const walletReady = !!actor;
  const networkOptions = [
    { value: 'internet_computer', label: t.networkIc },
    { value: 'ethereum', label: t.networkEth },
    { value: 'sepolia', label: t.networkSepolia },
    { value: 'base', label: t.networkBase },
    { value: 'polygon', label: t.networkPolygon },
    { value: 'arbitrum', label: t.networkArbitrum },
    { value: 'optimism', label: t.networkOptimism },
    { value: 'bsc', label: t.networkBsc },
    { value: 'avalanche', label: t.networkAvalanche },
    { value: 'solana', label: t.networkSolana },
  ];

  const icpTokenRows = overviewBalances
    .filter((item) => String(item?.network ?? '') === 'internet_computer')
    .map((item) => {
      const symbol = String(item?.symbol ?? '');
      const decimals = Number(item?.decimals ?? 8);
      return {
        symbol,
        name: String(item?.name ?? symbol),
        balance: item?.available ? item.amount.toString() : '-',
        decimals: Number.isFinite(decimals) ? decimals : 8,
        ledgerPrincipalText: fromOptText(item?.ledgerPrincipalText),
        tokenAddress: fromOptText(item?.tokenAddress),
      };
    });

  const tokenRows = viewNetwork === 'internet_computer'
    ? (
      icpTokenRows.length > 0
        ? icpTokenRows
        : [{ symbol: 'ICP', name: t.tokenIcpName, balance: balIcp, decimals: 8, ledgerPrincipalText: '', tokenAddress: '' }]
    )
    : (viewNetwork === 'solana'
      ? [
        { symbol: 'SOL', name: t.tokenSolName, balance: '-', decimals: 9, ledgerPrincipalText: '', tokenAddress: '' },
      ]
      : (() => {
        const evmRows = overviewBalances
          .filter((item) => String(item?.network ?? '') === viewNetwork)
          .map((item) => {
            const symbol = String(item?.symbol ?? '').trim() || 'ERC20';
            const decimals = Number(item?.decimals ?? 18);
            return {
              symbol,
              name: String(item?.name ?? symbol),
              balance: item?.available ? item.amount.toString() : '-',
              decimals: Number.isFinite(decimals) ? decimals : 18,
              ledgerPrincipalText: '',
              tokenAddress: fromOptText(item?.tokenAddress),
            };
          });
        if (evmRows.length > 0) return evmRows;
        return [
          { symbol: 'ETH', name: t.tokenEthName, balance: balEth, decimals: 18, ledgerPrincipalText: '', tokenAddress: '' },
          { symbol: 'ERC20', name: t.tokenErc20Name, balance: balErc20, decimals: 18, ledgerPrincipalText: '', tokenAddress: erc20TokenAddress.trim() },
        ];
      })());
  const tokenRowsWithDisplay = tokenRows.map((token) => ({
    ...token,
    displayBalance: formatTokenBalance(token.symbol, token.balance, token.decimals),
  }));

  const selectedToken = tokenRowsWithDisplay.find((token) => token.symbol === selectedTokenSymbol) ?? null;
  const primaryTokenSymbol = viewNetwork === 'internet_computer' ? 'ICP' : (viewNetwork === 'solana' ? 'SOL' : 'ETH');
  const primaryToken = tokenRowsWithDisplay.find((token) => token.symbol === primaryTokenSymbol) ?? tokenRowsWithDisplay[0];
  const heroBalance = primaryToken ? `${primaryToken.displayBalance} ${primaryToken.symbol}` : '--';
  const receiveAddress = viewNetwork === 'internet_computer' ? canisterPrincipalText : (viewNetwork === 'solana' ? '' : ethWallet);
  const selectedTokenAmountRaw = (selectedTokenDetail && selectedTokenDetail.available)
    ? selectedTokenDetail.amount.toString()
    : (selectedToken ? selectedToken.balance : '-');
  const selectedTokenLedger = selectedToken
    ? (
      fromOptText(selectedTokenDetail?.ledgerPrincipalText)
      || String(selectedToken.ledgerPrincipalText ?? '').trim()
    )
    : '';
  const selectedTokenContract = selectedToken
    ? (
      fromOptText(selectedTokenDetail?.tokenAddress)
      || String(selectedToken.tokenAddress ?? '').trim()
    )
    : '';
  const selectedTokenIsIcrc1 = selectedTokenLedger.length > 0;
  const selectedTokenIsEvmContract = selectedTokenContract.length > 0;
  const selectedTokenAddress = selectedToken
    ? (
      selectedTokenDetail && typeof selectedTokenDetail.address === 'string'
        ? selectedTokenDetail.address
        : (
          selectedToken.symbol === 'ICP' || selectedTokenIsIcrc1
            ? canisterPrincipalText
            : (selectedToken.symbol === 'SOL' ? '' : ethWallet)
        )
    )
    : '';
  const selectedTokenBalance = selectedToken ? formatTokenBalance(selectedToken.symbol, selectedTokenAmountRaw, selectedToken.decimals) : '0';
  const selectedTokenAmount = selectedToken ? `${selectedTokenBalance} ${selectedToken.symbol}` : '0';
  const sendAmountHint = selectedToken
    ? (
      selectedToken.symbol === 'ICP'
        ? t.sendAmountHintIcp
        : (
          selectedToken.symbol === 'ETH'
            ? t.sendAmountHintEth
            : (selectedTokenIsIcrc1 ? t.sendAmountHintIcrc1 : t.sendAmountHintBase)
        )
    )
    : t.sendAmountHintBase;
  const selectedTokenHistory = useMemo(() => {
    if (!selectedToken) return [];
    if (!Array.isArray(selectedTokenHistoryRaw) || selectedTokenHistoryRaw.length === 0) return [];

    const groups = [];
    const groupMap = new Map();
    selectedTokenHistoryRaw.forEach((entry, idx) => {
      const tsRaw = String(entry?.timestampNanos ?? '0');
      let ms = Date.now();
      try {
        ms = Number(BigInt(tsRaw) / 1000000n);
      } catch (_) {
        ms = Date.now();
      }
      const date = Number.isFinite(ms) ? new Date(ms) : new Date();
      const dateKey = `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
      const direction = entry?.direction ?? {};
      const isIncoming = Object.prototype.hasOwnProperty.call(direction, 'incoming');
      const amountRaw = String(entry?.amount ?? '0');
      const amountDisplay = formatTokenBalance(selectedToken.symbol, amountRaw, selectedToken.decimals);
      const counterparty = shortAddress(fromOptText(entry?.counterparty));
      const blockIndex = String(entry?.blockIndex ?? idx);
      const txHash = String(entry?.txHash ?? '').trim() || `block-${blockIndex}`;
      const item = {
        id: `${selectedToken.symbol}-${blockIndex}-${idx}`,
        kind: isIncoming ? 'receive' : 'send',
        address: counterparty,
        txHash,
        amount: `${isIncoming ? '+' : '-'}${amountDisplay} ${selectedToken.symbol}`,
        time: formatHistoryTime(date),
      };

      if (groupMap.has(dateKey)) {
        groups[groupMap.get(dateKey)].items.push(item);
      } else {
        groupMap.set(dateKey, groups.length);
        groups.push({
          date: formatHistoryDateLabel(date),
          items: [item],
        });
      }
    });
    return groups;
  }, [selectedToken, selectedTokenHistoryRaw, lang]);
  const receiveAddressRows = selectedToken
    ? (
      (selectedTokenDetail && Array.isArray(selectedTokenDetail.receiveAddresses) && selectedTokenDetail.receiveAddresses.length > 0)
        ? selectedTokenDetail.receiveAddresses.map((row, idx) => ({
          id: `${selectedToken.symbol}-${idx}-${String(row.kind)}`,
          title: receiveTitleByKind(String(row.kind), selectedToken.symbol),
          address: String(row.address ?? ''),
        }))
        : (
          viewNetwork === 'internet_computer'
            ? [
              { id: 'icp-only', title: t.receiveIcpOnly, address: canisterPrincipalText },
              { id: 'icrc', title: t.receiveIcrc, address: canisterPrincipalText },
            ]
            : (
              viewNetwork === 'solana'
                ? [{ id: 'sol', title: `${selectedToken.symbol} ${t.receiveEvm}`, address: '' }]
                : [{ id: 'evm', title: `${selectedToken.symbol} ${t.receiveEvm}`, address: selectedTokenAddress }]
            )
        )
    )
    : [];

  async function copyAddress(address) {
    if (!address) {
      setStatus(t.noAddress);
      return;
    }
    try {
      await navigator.clipboard.writeText(address);
      setStatus(t.copied);
    } catch (_) {
      setStatus(t.noAddress);
    }
  }

  async function copyReceiveAddress() {
    await copyAddress(receiveAddress);
  }

  function showReceiveQr(address) {
    if (!address) {
      setStatus(t.noAddress);
      return;
    }
    setStatus(t.qrNotReady);
  }

  function onAssetAction(action) {
    if (action === 'receive') {
      setReceiveModalOpen(true);
      return;
    }
    if (action === 'send') {
      if (!selectedToken) {
        setStatus(t.sendUnsupported);
        return;
      }
      if (selectedToken.symbol === 'SOL') {
        setStatus(t.sendUnsupported);
        return;
      }
      setSendPageOpen(true);
      setSendPageTo('');
      setSendPageAmount('');
      return;
    }
    if (action === 'swap') {
      setStatus(`${t.swap} · ${t.actionNotReady}`);
      return;
    }
    if (action === 'buy') {
      setStatus(`${t.buy} · ${t.actionNotReady}`);
      return;
    }
    setStatus(t.actionNotReady);
  }

  async function submitSendFromPage() {
    if (!actor || !selectedToken) return;
    const to = sendPageTo.trim();
    if (!to) {
      setStatus(t.sendNeedTo);
      return;
    }

    let amountBase = 0n;
    const amountText = sendPageAmount.trim();
    if (selectedToken.symbol === 'ICP') {
      const parsed = parseDecimalAmountToBaseUnits(amountText, 8);
      if (parsed == null) {
        setStatus(t.sendNeedAmount);
        return;
      }
      amountBase = parsed;
    } else if (selectedToken.symbol === 'ETH') {
      try {
        amountBase = parseEther(amountText);
      } catch (_) {
        setStatus(t.sendNeedAmount);
        return;
      }
    } else if (selectedTokenIsIcrc1) {
      const tokenDecimals = Number(selectedToken.decimals ?? 8);
      const decimals = Number.isFinite(tokenDecimals) && tokenDecimals >= 0 ? tokenDecimals : 8;
      const parsed = parseDecimalAmountToBaseUnits(amountText, decimals);
      if (parsed == null) {
        setStatus(t.sendNeedAmount);
        return;
      }
      amountBase = parsed;
    } else if (selectedTokenIsEvmContract) {
      try {
        amountBase = BigInt(amountText || '0');
      } catch (_) {
        setStatus(t.sendNeedAmount);
        return;
      }
    } else {
      setStatus(t.sendUnsupported);
      return;
    }

    if (amountBase <= 0n) {
      setStatus(t.sendNeedAmount);
      return;
    }

    let req = null;
    if (selectedToken.symbol === 'ICP') {
      req = {
        kind: { icp: null },
        network: [],
        rpcUrl: [],
        to,
        amount: amountBase,
        tokenAddress: [],
        ledgerPrincipalText: [],
        fee: [],
      };
    } else if (selectedTokenIsIcrc1) {
      const ledgerText = selectedTokenLedger.trim();
      if (!ledgerText) {
        setStatus(t.sendMissingLedger);
        return;
      }
      req = {
        kind: { icrc1: null },
        network: [],
        rpcUrl: [],
        to,
        amount: amountBase,
        tokenAddress: [],
        ledgerPrincipalText: [ledgerText],
        fee: [],
      };
    } else if (selectedToken.symbol === 'ETH') {
      req = {
        kind: { eth: null },
        network: [viewNetwork],
        rpcUrl: toOptText(ethRpcUrl),
        to,
        amount: amountBase,
        tokenAddress: [],
        ledgerPrincipalText: [],
        fee: [],
      };
    } else if (selectedTokenIsEvmContract) {
      const tokenAddress = selectedTokenContract || erc20TokenAddress.trim();
      if (!tokenAddress) {
        setStatus(t.sendMissingToken);
        return;
      }
      req = {
        kind: { erc20: null },
        network: [viewNetwork],
        rpcUrl: toOptText(ethRpcUrl),
        to,
        amount: amountBase,
        tokenAddress: [tokenAddress],
        ledgerPrincipalText: [],
        fee: [],
      };
    }

    if (!req) {
      setStatus(t.sendUnsupported);
      return;
    }

    setBusy(true);
    setStatus(t.sending);
    try {
      const res = await actor.wallet_send(req);
      if ('ok' in res) {
        setStatus(`${t.sendSuccess} tx: ${res.ok.txId}`);
        setSendPageOpen(false);
        setSendPageTo('');
        setSendPageAmount('');
        await refreshOverview(actor);
      } else {
        setStatus(`${t.errPrefix}${res.err}`);
      }
    } catch (e) {
      setStatus(`${t.exPrefix}${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  function onSwitchNetwork(nextNetwork) {
    overviewRequestSeqRef.current += 1;
    // Clear stale balances immediately to avoid showing previous-network ETH.
    setBalIcp('-');
    setBalEth('-');
    setBalIcrc1('-');
    setBalErc20('-');
    setOverviewBalances([]);
    setViewNetwork(nextNetwork);
    setSelectedTokenSymbol('');
    setSelectedTokenDetail(null);
    setSelectedTokenHistoryRaw([]);
    setSendPageOpen(false);
    setSendPageTo('');
    setSendPageAmount('');
    setReceiveModalOpen(false);
    if (isEvmNetwork(nextNetwork)) {
      setEthNetwork(nextNetwork);
    }
  }

  return (
    <div className="walletPage">
      {!selectedToken && (
        <header className="walletTopBar">
          <div className="walletNetSelect">
            <span>{t.network}</span>
            <select value={viewNetwork} onChange={(e) => onSwitchNetwork(e.target.value)}>
              {networkOptions.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </div>
          <div className="walletHeaderActions">
            <button type="button" onClick={() => (window.location.href = './')}>{t.back}</button>
            <button type="button" onClick={() => setLang((v) => (v === 'zh' ? 'en' : 'zh'))}>{t.lang}</button>
          </div>
        </header>
      )}

      {selectedToken ? (
        sendPageOpen ? (
          <section className="walletSendPage">
            <div className="walletSendCard panel">
              <div className="walletAssetHeroTop">
                <button type="button" className="walletAssetRoundBtn" onClick={() => setSendPageOpen(false)}>
                  {'<'}
                </button>
                <button type="button" className="walletAssetRoundBtn" onClick={() => setSendPageOpen(false)}>
                  x
                </button>
              </div>
              <div className="walletAssetTokenBadge">{selectedToken.symbol}</div>
              <h3>{t.sendPageTitle} {selectedToken.symbol}</h3>

              <div className="walletSendForm">
                <label htmlFor="wallet-send-to">{t.sendToLabel}</label>
                <input
                  id="wallet-send-to"
                  type="text"
                  value={sendPageTo}
                  onChange={(e) => setSendPageTo(e.target.value)}
                  placeholder={selectedTokenAddress || t.sendToLabel}
                />

                <label htmlFor="wallet-send-amount">{t.sendAmountLabel}</label>
                <input
                  id="wallet-send-amount"
                  type="text"
                  value={sendPageAmount}
                  onChange={(e) => setSendPageAmount(e.target.value)}
                  placeholder={sendAmountHint}
                />
                <small>{sendAmountHint}</small>
              </div>

              <div className="walletSendActions">
                <button type="button" onClick={() => setSendPageOpen(false)} disabled={busy}>
                  {t.close}
                </button>
                <button type="button" onClick={() => void submitSendFromPage()} disabled={busy || !walletReady}>
                  {busy ? t.sending : t.sendConfirm}
                </button>
              </div>
            </div>
          </section>
        ) : (
          <section className="walletAssetPage">
            <div className="walletAssetHero panel">
              <div className="walletAssetHeroTop">
                <button
                  type="button"
                  className="walletAssetRoundBtn"
                  onClick={() => {
                    setSelectedTokenSymbol('');
                    setSendPageOpen(false);
                    setSendPageTo('');
                    setSendPageAmount('');
                    setReceiveModalOpen(false);
                  }}
                >
                  {'<'}
                </button>
                <button type="button" className="walletAssetRoundBtn" onClick={() => setStatus(t.actionNotReady)}>
                  ...
                </button>
              </div>
              <div className="walletAssetTokenBadge">{selectedToken.symbol}</div>
              <div className="walletAssetBalance">{selectedTokenAmount}</div>
              <div className="walletAssetOnchain">{t.onChainBalance}: {selectedTokenAmount}</div>
              <div className="walletAssetUsd">{t.usdValuePlaceholder}</div>
              <div className="walletAssetActionGrid">
                <button type="button" onClick={() => onAssetAction('receive')}>{t.receive}</button>
                <button type="button" onClick={() => onAssetAction('send')}>{t.send}</button>
                <button type="button" onClick={() => onAssetAction('swap')}>{t.swap}</button>
                <button type="button" onClick={() => onAssetAction('buy')}>{t.buy}</button>
              </div>
            </div>

            <div className="walletAssetAddress panel">
              <div className="walletAssetAddressHead">
                <strong>{t.receiveAddressTitle}</strong>
                <button
                  type="button"
                  onClick={() => void copyAddress(selectedTokenAddress)}
                  disabled={!walletReady || !selectedTokenAddress}
                >
                  {t.receive}
                </button>
              </div>
              <p>{t.receiveAddressHint}</p>
              <div className="walletAssetAddressValue">{selectedTokenAddress || '-'}</div>
            </div>

            <div className="walletAssetHistory">
              <h3>{t.transactionHistory}</h3>
              {selectedTokenHistory.length === 0 ? (
                <div className="walletAssetEmpty panel">{t.noHistory}</div>
              ) : (
                selectedTokenHistory.map((group) => (
                  <div className="walletAssetHistoryGroup" key={`${selectedToken.symbol}-${group.date}`}>
                    <div className="walletAssetHistoryDate">{group.date}</div>
                    <div className="walletAssetHistoryList">
                      {group.items.map((item) => (
                        <div className="walletTxItem panel" key={`${group.date}-${item.id}`}>
                          <div className="walletTxLeft">
                            <div className="walletTxIcon">{selectedToken.symbol.slice(0, 2)}</div>
                            <div className="walletTxMeta">
                              <strong>{item.kind === 'send' ? t.send : t.receive}</strong>
                              <span>{item.kind === 'send' ? `${t.txTo} ${item.address}` : `${t.txFrom} ${item.address}`}</span>
                              <span className="walletTxHash">{t.txHashLabel}: {item.txHash}</span>
                            </div>
                          </div>
                          <div className="walletTxRight">
                            <strong className={item.kind === 'receive' ? 'isIncome' : 'isOutcome'}>{item.amount}</strong>
                            <span>{item.time}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))
              )}
            </div>
          </section>
        )
      ) : (
        <>
          <section className="walletHero panel">
            <div className="walletHeroBalance">{heroBalance}</div>
            <div className="walletHeroSub">{t.totalBalance}</div>
            <div className="walletHeroActions">
              <button type="button" onClick={() => void copyReceiveAddress()} disabled={!walletReady}>{t.receive}</button>
              <button type="button" onClick={() => setStatus(t.send)}>{t.send}</button>
              <button type="button" onClick={() => setStatus(t.swap)}>{t.swap}</button>
            </div>
          </section>

          <section className="walletTokenArea panel">
            <div className="walletTokenTabs">
              <button type="button" className="active">{t.tokenTab}</button>
              <button type="button" disabled>{t.nftTab}</button>
              <button type="button" onClick={() => void refreshBalances()} disabled={busy || !walletReady}>{t.refreshBalances}</button>
            </div>

            {viewNetwork === 'internet_computer' && (
              <div className="walletAddTokenRow">
                <label htmlFor="wallet-add-icrc1-ledger">{t.addIcrc1Title}</label>
                <div className="walletAddTokenControls">
                  <input
                    id="wallet-add-icrc1-ledger"
                    type="text"
                    value={icrc1AddLedger}
                    onChange={(e) => setIcrc1AddLedger(e.target.value)}
                    placeholder={t.addIcrc1Placeholder}
                    disabled={busy || !walletReady}
                  />
                  <button type="button" onClick={() => void addIcrc1Token()} disabled={busy || !walletReady}>
                    {t.addIcrc1Btn}
                  </button>
                </div>
              </div>
            )}

            {isEvmNetwork(viewNetwork) && (
              <div className="walletAddTokenRow">
                <label htmlFor="wallet-add-evm-token">{t.addEvmTokenTitle}</label>
                <div className="walletAddTokenControls">
                  <input
                    id="wallet-add-evm-token"
                    type="text"
                    value={evmAddTokenAddress}
                    onChange={(e) => setEvmAddTokenAddress(e.target.value)}
                    placeholder={t.addEvmTokenPlaceholder}
                    disabled={busy || !walletReady}
                  />
                  <input
                    type="text"
                    value={evmAddTokenSymbol}
                    onChange={(e) => setEvmAddTokenSymbol(e.target.value)}
                    placeholder={t.addEvmTokenSymbolPlaceholder}
                    disabled={busy || !walletReady}
                  />
                  <button type="button" onClick={() => void addEvmToken()} disabled={busy || !walletReady}>
                    {t.addEvmTokenBtn}
                  </button>
                </div>
              </div>
            )}

            <div className="walletTokenList">
              {tokenRowsWithDisplay.map((token) => (
                <button
                  type="button"
                  className="walletTokenRow walletTokenRowButton"
                  key={`${viewNetwork}-${token.symbol}`}
                  onClick={() => {
                    setSelectedTokenSymbol(token.symbol);
                    setSendPageOpen(false);
                    setSendPageTo('');
                    setSendPageAmount('');
                  }}
                  disabled={!walletReady}
                >
                  <div className="walletTokenLeft">
                    <div className="walletTokenIcon">{token.symbol.slice(0, 2)}</div>
                    <div className="walletTokenMeta">
                      <strong>{token.symbol}</strong>
                      <span>{token.name}</span>
                    </div>
                  </div>
                  <div className="walletTokenRight">
                    <strong className="walletTokenBalance">{token.displayBalance}</strong>
                    <span className="walletTokenArrow">›</span>
                  </div>
                </button>
              ))}
            </div>
          </section>
        </>
      )}

      <footer className="walletFooter panel">
        <span>{t.status}</span>
        <strong>{status || '-'}</strong>
      </footer>

      {receiveModalOpen && selectedToken && (
        <div className="walletReceiveOverlay" role="dialog" aria-modal="true" aria-label={t.receiveSheetTitle}>
          <section className="walletReceiveModal panel">
            <div className="walletReceiveModalHead">
              <strong>{t.receiveSheetTitle}</strong>
              <button type="button" className="walletAssetRoundBtn" onClick={() => setReceiveModalOpen(false)}>x</button>
            </div>

            <div className="walletReceiveModalBody">
              {receiveAddressRows.map((row) => (
                <div className="walletReceiveAddressBlock" key={`${selectedToken.symbol}-${row.id}`}>
                  <h4>{row.title}</h4>
                  <div className="walletReceiveAddressRow">
                    <div className="walletReceiveAddressMain">
                      <div className="walletReceiveAddressLogo">{selectedToken.symbol.slice(0, 2)}</div>
                      <span>{row.address || '-'}</span>
                    </div>
                    <div className="walletReceiveAddressActions">
                      <button
                        type="button"
                        className="walletReceiveIconBtn"
                        onClick={() => showReceiveQr(row.address)}
                        disabled={!row.address}
                      >
                        {t.qrCode}
                      </button>
                      <button
                        type="button"
                        className="walletReceiveIconBtn"
                        onClick={() => void copyAddress(row.address)}
                        disabled={!row.address}
                      >
                        {t.copy}
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="walletReceiveModalFoot">
              <button type="button" onClick={() => setReceiveModalOpen(false)}>{t.receiveModalDone}</button>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
