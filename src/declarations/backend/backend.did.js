export const idlFactory = ({ IDL }) => {
  const Provider = IDL.Variant({
    'openai' : IDL.Null,
    'google' : IDL.Null,
    'anthropic' : IDL.Null,
  });
  const SendOptions = IDL.Record({
    'model' : IDL.Text,
    'provider' : Provider,
    'temperature' : IDL.Opt(IDL.Float64),
    'apiKey' : IDL.Text,
    'systemPrompt' : IDL.Opt(IDL.Text),
    'includeHistory' : IDL.Bool,
    'maxTokens' : IDL.Opt(IDL.Nat),
    'skillNames' : IDL.Vec(IDL.Text),
  });
  const Result = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const AgentWallet = IDL.Record({
    'principal' : IDL.Principal,
    'derivationPathHex' : IDL.Vec(IDL.Text),
    'publicKeyHex' : IDL.Text,
    'keyName' : IDL.Text,
    'principalText' : IDL.Text,
    'chainCodeHex' : IDL.Text,
  });
  const WalletResult = IDL.Variant({ 'ok' : AgentWallet, 'err' : IDL.Text });
  const EcdsaPublicKeyOut = IDL.Record({
    'principal' : IDL.Principal,
    'derivationPathHex' : IDL.Vec(IDL.Text),
    'publicKeyHex' : IDL.Text,
    'keyName' : IDL.Text,
    'principalText' : IDL.Text,
    'chainCodeHex' : IDL.Text,
  });
  const EcdsaPublicKeyResult = IDL.Variant({
    'ok' : EcdsaPublicKeyOut,
    'err' : IDL.Text,
  });
  const HeaderField = IDL.Tuple(IDL.Text, IDL.Text);
  const InHttpRequest = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
  });
  const InHttpResponse = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
    'upgrade' : IDL.Opt(IDL.Bool),
    'streaming_strategy' : IDL.Opt(
      IDL.Variant({
        'Callback' : IDL.Record({
          'token' : IDL.Vec(IDL.Nat8),
          'callback' : IDL.Func([], [], ['query']),
        }),
      })
    ),
    'status_code' : IDL.Nat16,
  });
  const HttpHeader = IDL.Record({ 'value' : IDL.Text, 'name' : IDL.Text });
  const HttpResponsePayload = IDL.Record({
    'status' : IDL.Nat,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HttpHeader),
  });
  const TransformArgs = IDL.Record({
    'context' : IDL.Vec(IDL.Nat8),
    'response' : HttpResponsePayload,
  });
  const ModelsResult = IDL.Variant({
    'ok' : IDL.Vec(IDL.Text),
    'err' : IDL.Text,
  });
  const Role = IDL.Variant({
    'tool' : IDL.Null,
    'user' : IDL.Null,
    'assistant' : IDL.Null,
    'system' : IDL.Null,
  });
  const ChatMessage = IDL.Record({
    'content' : IDL.Text,
    'role' : Role,
    'tsNs' : IDL.Int,
  });
  const SessionSummary = IDL.Record({
    'id' : IDL.Text,
    'updatedAtNs' : IDL.Int,
    'messageCount' : IDL.Nat,
  });
  const SendOk = IDL.Record({
    'raw' : IDL.Opt(IDL.Text),
    'assistant' : ChatMessage,
  });
  const SendResult = IDL.Variant({ 'ok' : SendOk, 'err' : IDL.Text });
  const SignWithEcdsaOut = IDL.Record({
    'principal' : IDL.Principal,
    'messageHashHex' : IDL.Text,
    'derivationPathHex' : IDL.Vec(IDL.Text),
    'signatureHex' : IDL.Text,
    'keyName' : IDL.Text,
    'principalText' : IDL.Text,
  });
  const SignWithEcdsaResult = IDL.Variant({
    'ok' : SignWithEcdsaOut,
    'err' : IDL.Text,
  });
  const TgStatus = IDL.Record({
    'hasLlmConfig' : IDL.Bool,
    'configured' : IDL.Bool,
    'hasSecret' : IDL.Bool,
  });
  const ToolResult = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const BalanceResult = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  const SendEthResult = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const SendIcpResult = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  const SendIcrc1Result = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  return IDL.Service({
    'admin_set_llm_opts' : IDL.Func([SendOptions], [], []),
    'admin_set_tg' : IDL.Func([IDL.Text, IDL.Opt(IDL.Text)], [], []),
    'admin_tg_set_webhook' : IDL.Func([IDL.Text], [Result], []),
    'agent_wallet' : IDL.Func([], [WalletResult], []),
    'canister_principal' : IDL.Func([], [IDL.Principal], ['query']),
    'ecdsa_public_key' : IDL.Func(
        [IDL.Vec(IDL.Vec(IDL.Nat8)), IDL.Opt(IDL.Text)],
        [EcdsaPublicKeyResult],
        [],
      ),
    'http_request' : IDL.Func([InHttpRequest], [InHttpResponse], ['query']),
    'http_request_update' : IDL.Func([InHttpRequest], [InHttpResponse], []),
    'http_transform' : IDL.Func(
        [TransformArgs],
        [HttpResponsePayload],
        ['query'],
      ),
    'models_list' : IDL.Func([Provider, IDL.Text], [ModelsResult], []),
    'owner_get' : IDL.Func([], [IDL.Opt(IDL.Principal)], ['query']),
    'sessions_create' : IDL.Func([IDL.Text], [], []),
    'sessions_history' : IDL.Func(
        [IDL.Text, IDL.Nat],
        [IDL.Vec(ChatMessage)],
        [],
      ),
    'sessions_list' : IDL.Func([], [IDL.Vec(SessionSummary)], []),
    'sessions_list_for' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(SessionSummary)],
        ['query'],
      ),
    'sessions_reset' : IDL.Func([IDL.Text], [], []),
    'sessions_send' : IDL.Func(
        [IDL.Text, IDL.Text, SendOptions],
        [SendResult],
        [],
      ),
    'sign_with_ecdsa' : IDL.Func(
        [IDL.Vec(IDL.Nat8), IDL.Vec(IDL.Vec(IDL.Nat8)), IDL.Opt(IDL.Text)],
        [SignWithEcdsaResult],
        [],
      ),
    'skills_delete' : IDL.Func([IDL.Text], [IDL.Bool], []),
    'skills_get' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Text)], []),
    'skills_list' : IDL.Func([], [IDL.Vec(IDL.Text)], []),
    'skills_put' : IDL.Func([IDL.Text, IDL.Text], [], []),
    'tg_status' : IDL.Func([], [TgStatus], []),
    'tools_invoke' : IDL.Func([IDL.Text, IDL.Vec(IDL.Text)], [ToolResult], []),
    'tools_list' : IDL.Func([], [IDL.Vec(IDL.Text)], []),
    'wallet_balance_erc20' : IDL.Func(
        [IDL.Text, IDL.Opt(IDL.Text), IDL.Text],
        [BalanceResult],
        [],
      ),
    'wallet_balance_eth' : IDL.Func(
        [IDL.Text, IDL.Opt(IDL.Text)],
        [BalanceResult],
        [],
      ),
    'wallet_balance_icp' : IDL.Func([], [BalanceResult], []),
    'wallet_balance_icrc1' : IDL.Func([IDL.Text], [BalanceResult], []),
    'wallet_send_erc20' : IDL.Func(
        [IDL.Text, IDL.Opt(IDL.Text), IDL.Text, IDL.Text, IDL.Nat],
        [SendEthResult],
        [],
      ),
    'wallet_send_eth' : IDL.Func(
        [IDL.Text, IDL.Opt(IDL.Text), IDL.Text, IDL.Nat],
        [SendEthResult],
        [],
      ),
    'wallet_send_eth_raw' : IDL.Func(
        [IDL.Text, IDL.Opt(IDL.Text), IDL.Text],
        [SendEthResult],
        [],
      ),
    'wallet_send_icp' : IDL.Func([IDL.Text, IDL.Nat64], [SendIcpResult], []),
    'wallet_send_icrc1' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Nat, IDL.Opt(IDL.Nat)],
        [SendIcrc1Result],
        [],
      ),
    'whoami' : IDL.Func([], [IDL.Text], []),
  });
};
export const init = ({ IDL }) => { return []; };
