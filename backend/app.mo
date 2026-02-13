import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import HttpTypes "./openclaw/http/HttpTypes";
import ChannelRouter "./openclaw/channels/ChannelRouter";
import DiscordChannelAdapter "./openclaw/channels/DiscordChannelAdapter";
import TelegramChannelAdapter "./openclaw/channels/TelegramChannelAdapter";
import Llm "./openclaw/llm/Llm";
import Sessions "./openclaw/core/Sessions";
import Hooks "./openclaw/core/Hooks";
import Skills "./openclaw/core/Skills";
import Store "./openclaw/core/Store";
import Tools "./openclaw/core/Tools";
import Telegram "./openclaw/telegram/Telegram";
import Types "./openclaw/core/Types";
import Wallet "./openclaw/wallet/Wallet";
import WalletIcp "./openclaw/wallet/WalletIcp";
import WalletEvm "./openclaw/wallet/WalletEvm";
import CkEthTrade "./openclaw/wallet/CkEthTrade";
import KeyVault "./openclaw/core/KeyVault";
import LlmToolRouter "./openclaw/llm/LlmToolRouter";
import Migration "migration";

persistent actor OpenClawOnICP {
  // -----------------------------
  // Public types (Candid surface)
  // -----------------------------

  public type Provider = Types.Provider;
  public type Role = Types.Role;
  public type ChatMessage = Types.ChatMessage;
  public type SessionSummary = Types.SessionSummary;
  public type SendOptions = Types.SendOptions;
  public type SendOk = Types.SendOk;
  public type SendResult = Types.SendResult;
  public type ToolResult = Types.ToolResult;
  public type HookEntry = Hooks.HookEntry;

  public type ModelsResult = Result.Result<[Text], Text>;
  public type SendIcpResult = Result.Result<Nat, Text>;
  public type SendIcrc1Result = Result.Result<Nat, Text>;
  public type SendEthResult = Result.Result<Text, Text>;
  public type BuyCkEthResult = Result.Result<Text, Text>;
  public type EthAddressResult = Result.Result<Text, Text>;
  public type BalanceResult = Result.Result<Nat, Text>;
  public type WalletResult = Wallet.WalletResult;
  public type EcdsaPublicKeyResult = Wallet.EcdsaPublicKeyResult;
  public type SignWithEcdsaResult = Wallet.SignWithEcdsaResult;
  public type AgentWallet = Wallet.AgentWallet;
  public type EcdsaPublicKeyOut = Wallet.EcdsaPublicKeyOut;
  public type SignWithEcdsaOut = Wallet.SignWithEcdsaOut;

  public type TgStatus = {
    configured : Bool;
    hasSecret : Bool;
    hasLlmConfig : Bool;
  };

  public type DiscordStatus = {
    configured : Bool;
    hasProxySecret : Bool;
    hasLlmConfig : Bool;
  };

  public type CkEthStatus = {
    hasIcpswapQuoteUrl : Bool;
    hasKongswapQuoteUrl : Bool;
    hasIcpswapBroker : Bool;
    hasKongswapBroker : Bool;
  };

  // -----------------------------
  // Minimal HTTP outcall interface
  // -----------------------------

  type HttpResponsePayload = HttpTypes.HttpResponsePayload;
  type TransformArgs = HttpTypes.TransformArgs;
  type HttpRequestArgs = HttpTypes.HttpRequestArgs;

  transient let ic : Llm.Http = actor ("aaaaa-aa");
  transient let ic00 : Wallet.Ic00 = actor ("aaaaa-aa");
  transient let icpLedgerMainnetPrincipal : Principal = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
  transient let icpLedgerLocalPrincipal : Principal = Principal.fromText("ulvla-h7777-77774-qaacq-cai");

  // -----------------------------
  // Inbound canister HTTP (for Telegram webhooks)
  // -----------------------------

  type HeaderField = ChannelRouter.HeaderField;
  type InHttpRequest = ChannelRouter.InHttpRequest;
  type InHttpResponse = ChannelRouter.InHttpResponse;

  public query func http_transform(args : TransformArgs) : async HttpResponsePayload {
    { status = args.response.status; headers = []; body = args.response.body };
  };

  // -----------------------------
  // Admin + Telegram configuration
  // -----------------------------

  var owner : ?Principal = null;
  var tgBotToken : ?Text = null;
  var tgSecretToken : ?Text = null;
  var tgLlmOpts : ?SendOptions = null;
  var discordProxySecret : ?Text = null;
  var ckethIcpswapQuoteUrl : ?Text = null;
  var ckethKongswapQuoteUrl : ?Text = null;
  var ckethIcpswapBrokerCanisterText : ?Text = null;
  var ckethKongswapBrokerCanisterText : ?Text = null;
  var llmApiKeysEnc : [(Text, Text)] = [];
  var migrationState : ?Migration.State = null;

  func assertOwner(caller : Principal) {
    if (Principal.isAnonymous(caller)) {
      Debug.trap("login required")
    };
    switch (owner) {
      case null { owner := ?caller };
      case (?o) { if (o != caller) { Debug.trap("not authorized") } };
    }
  };

  func assertOwnerQuery(caller : Principal) {
    switch (owner) {
      case null { Debug.trap("not authorized") };
      case (?o) { if (o != caller) { Debug.trap("not authorized") } };
    }
  };

  public query func owner_get() : async ?Principal {
    owner
  };

  public shared ({ caller }) func admin_set_tg(botToken : Text, secretToken : ?Text) : async () {
    assertOwner(caller);
    tgBotToken := ?Text.trim(botToken, #char ' ');
    tgSecretToken := secretToken;
  };

  public shared ({ caller }) func admin_set_llm_opts(opts : SendOptions) : async () {
    assertOwner(caller);
    tgLlmOpts := ?opts;
  };

  public shared ({ caller }) func admin_set_discord(proxySecret : ?Text) : async () {
    assertOwner(caller);
    discordProxySecret := switch (proxySecret) {
      case null null;
      case (?s) {
        let t = Text.trim(s, #char ' ');
        if (Text.size(t) == 0) null else ?t;
      };
    };
  };

  public shared ({ caller }) func admin_set_cketh_broker(canisterText : ?Text) : async () {
    assertOwner(caller);
    ckethIcpswapBrokerCanisterText := normalizeOptText(canisterText);
  };

  public shared ({ caller }) func admin_set_cketh_brokers(icpswapCanisterText : ?Text, kongswapCanisterText : ?Text) : async () {
    assertOwner(caller);
    ckethIcpswapBrokerCanisterText := normalizeOptText(icpswapCanisterText);
    ckethKongswapBrokerCanisterText := normalizeOptText(kongswapCanisterText);
  };

  public shared ({ caller }) func admin_set_cketh_quote_sources(icpswapQuoteUrl : ?Text, kongswapQuoteUrl : ?Text) : async () {
    assertOwner(caller);
    ckethIcpswapQuoteUrl := normalizeOptText(icpswapQuoteUrl);
    ckethKongswapQuoteUrl := normalizeOptText(kongswapQuoteUrl);
  };

  public shared ({ caller }) func admin_set_provider_api_key(provider : Provider, apiKey : Text) : async () {
    assertOwner(caller);
    llmApiKeysEnc := KeyVault.setProviderApiKey(llmApiKeysEnc, provider, apiKey);
  };

  public shared query ({ caller }) func admin_has_provider_api_key(provider : Provider) : async Bool {
    assertOwnerQuery(caller);
    KeyVault.hasProviderApiKey(llmApiKeysEnc, provider)
  };

  func resolveApiKey(provider : Provider, providedApiKey : Text) : Result.Result<Text, Text> {
    KeyVault.resolveApiKey(llmApiKeysEnc, provider, providedApiKey)
  };

  func normalizeOptText(v : ?Text) : ?Text {
    switch (v) {
      case null null;
      case (?s) {
        let t = Text.trim(s, #char ' ');
        if (Text.size(t) == 0) null else ?t;
      };
    }
  };

  public shared ({ caller }) func admin_tg_set_webhook(webhookUrl : Text) : async Result.Result<Text, Text> {
    assertOwner(caller);
    switch (tgBotToken) {
      case null return #err("telegram bot token not configured");
      case (?token) {
        await Telegram.setWebhook(ic, http_transform, defaultHttpCycles, token, webhookUrl, tgSecretToken)
      };
    }
  };

  public shared ({ caller }) func tg_status() : async TgStatus {
    assertOwner(caller);
    {
      configured = (tgBotToken != null);
      hasSecret = (tgSecretToken != null);
      hasLlmConfig = (tgLlmOpts != null);
    }
  };

  public shared ({ caller }) func discord_status() : async DiscordStatus {
    assertOwner(caller);
    {
      configured = (discordProxySecret != null);
      hasProxySecret = (discordProxySecret != null);
      hasLlmConfig = (tgLlmOpts != null);
    }
  };

  public shared ({ caller }) func cketh_status() : async CkEthStatus {
    assertOwner(caller);
    {
      hasIcpswapQuoteUrl = (ckethIcpswapQuoteUrl != null);
      hasKongswapQuoteUrl = (ckethKongswapQuoteUrl != null);
      hasIcpswapBroker = (ckethIcpswapBrokerCanisterText != null);
      hasKongswapBroker = (ckethKongswapBrokerCanisterText != null);
    }
  };

  // Canister HTTP entrypoint (query): upgrade Telegram webhooks to update.
  public query func http_request(req : InHttpRequest) : async InHttpResponse {
    ChannelRouter.routeQuery(req, [
      TelegramChannelAdapter.queryHandler(),
      DiscordChannelAdapter.queryHandler(),
    ])
  };

  // Canister HTTP update handler: process Telegram webhook.
  public shared ({ caller = _ }) func http_request_update(req : InHttpRequest) : async InHttpResponse {
    let tgOptsResolved : ?SendOptions = switch (tgLlmOpts) {
      case null null;
      case (?opts) {
        switch (resolveApiKey(opts.provider, opts.apiKey)) {
          case (#err(_)) null;
          case (#ok(k)) {
            ?{
              provider = opts.provider;
              model = opts.model;
              apiKey = k;
              systemPrompt = opts.systemPrompt;
              maxTokens = opts.maxTokens;
              temperature = opts.temperature;
              skillNames = opts.skillNames;
              includeHistory = opts.includeHistory;
            }
          };
        }
      };
    };

    await ChannelRouter.routeUpdate(
      req,
      [
        TelegramChannelAdapter.updateHandler({
          tgBotToken = tgBotToken;
          tgSecretToken = tgSecretToken;
          tgLlmOpts = tgOptsResolved;
          users = users;
          canisterPrincipal = Principal.fromActor(OpenClawOnICP);
          nowNs = nowNs;
          modelCaller = modelCaller;
          toolCaller = toolCaller;
          toolSpecs = llmToolSpecs;
          ic = ic;
          transformFn = http_transform;
          defaultHttpCycles = defaultHttpCycles;
        }),
        DiscordChannelAdapter.updateHandler({
          llmOpts = tgOptsResolved;
          proxySecret = discordProxySecret;
          users = users;
          canisterPrincipal = Principal.fromActor(OpenClawOnICP);
          nowNs = nowNs;
          modelCaller = modelCaller;
          toolCaller = toolCaller;
          toolSpecs = llmToolSpecs;
        }),
      ],
    )
  };

  // -----------------------------
  // State + upgrades
  // -----------------------------

  var usersStore : [(Principal, Store.UserStore)] = [];
  transient var users = Store.initUsers();

  system func preupgrade() {
    usersStore := Store.toStore(users);
    migrationState := ?Migration.capture(
      owner,
      tgBotToken,
      tgSecretToken,
      tgLlmOpts,
      usersStore,
      llmApiKeysEnc,
      discordProxySecret,
      ckethIcpswapQuoteUrl,
      ckethKongswapQuoteUrl,
      ckethIcpswapBrokerCanisterText,
      ckethKongswapBrokerCanisterText,
    );
  };

  system func postupgrade() {
    switch (migrationState) {
      case (?s) {
        let restored = Migration.migrate(s);
        owner := restored.owner;
        tgBotToken := restored.tgBotToken;
        tgSecretToken := restored.tgSecretToken;
        tgLlmOpts := restored.tgLlmOpts;
        usersStore := restored.usersStore;
        llmApiKeysEnc := restored.llmApiKeysEnc;
        discordProxySecret := restored.discordProxySecret;
        ckethIcpswapQuoteUrl := restored.ckethIcpswapQuoteUrl;
        ckethKongswapQuoteUrl := restored.ckethKongswapQuoteUrl;
        ckethIcpswapBrokerCanisterText := restored.ckethIcpswapBrokerCanisterText;
        ckethKongswapBrokerCanisterText := restored.ckethKongswapBrokerCanisterText;
      };
      case null {
        // Keep persisted state as-is when there is no migration snapshot.
      };
    };
    users := Store.fromStore(usersStore);
  };

  func nowNs() : Int { Time.now() };

  func ckethVenueConfig() : CkEthTrade.VenueConfig {
    {
      ic = ic;
      transformFn = http_transform;
      httpCycles = defaultHttpCycles;
      icpswapQuoteUrl = ckethIcpswapQuoteUrl;
      kongswapQuoteUrl = ckethKongswapQuoteUrl;
      icpswapBroker = ckethIcpswapBrokerCanisterText;
      kongswapBroker = ckethKongswapBrokerCanisterText;
    }
  };

  public shared ({ caller }) func whoami() : async Text {
    assertOwner(caller);
    Principal.toText(caller)
  };

  public shared ({ caller }) func ecdsa_public_key(derivationPath : [Blob], keyName : ?Text) : async EcdsaPublicKeyResult {
    assertOwner(caller);
    await WalletEvm.ecdsaPublicKey(ic00, caller, Principal.fromActor(OpenClawOnICP), derivationPath, keyName)
  };

  public shared ({ caller }) func sign_with_ecdsa(messageHash : Blob, derivationPath : [Blob], keyName : ?Text) : async SignWithEcdsaResult {
    assertOwner(caller);
    await WalletEvm.signWithEcdsa(ic00, caller, messageHash, derivationPath, keyName)
  };

  public shared ({ caller }) func agent_wallet() : async WalletResult {
    assertOwner(caller);
    await WalletEvm.agentWallet(ic00, caller, Principal.fromActor(OpenClawOnICP))
  };

  public shared query ({ caller }) func canister_principal() : async Principal {
    assertOwnerQuery(caller);
    Principal.fromActor(OpenClawOnICP)
  };

  public shared ({ caller }) func wallet_send_icp(toPrincipalText : Text, amountE8s : Nat64) : async SendIcpResult {
    assertOwner(caller);
    await WalletIcp.sendIcp(icpLedgerLocalPrincipal, icpLedgerMainnetPrincipal, toPrincipalText, amountE8s)
  };

  public shared ({ caller }) func wallet_send_icrc1(ledgerPrincipalText : Text, toPrincipalText : Text, amount : Nat, fee : ?Nat) : async SendIcrc1Result {
    assertOwner(caller);
    await WalletIcp.sendIcrc1(ledgerPrincipalText, toPrincipalText, amount, fee)
  };

  public shared ({ caller }) func wallet_balance_icp() : async BalanceResult {
    assertOwner(caller);
    await WalletIcp.balanceIcp(icpLedgerLocalPrincipal, icpLedgerMainnetPrincipal, Principal.fromActor(OpenClawOnICP))
  };

  public shared ({ caller }) func wallet_balance_icrc1(ledgerPrincipalText : Text) : async BalanceResult {
    assertOwner(caller);
    await WalletIcp.balanceIcrc1(ledgerPrincipalText, Principal.fromActor(OpenClawOnICP))
  };

  public shared ({ caller }) func wallet_send_eth_raw(network : Text, rpcUrl : ?Text, rawTxHex : Text) : async SendEthResult {
    assertOwner(caller);
    await WalletEvm.sendRaw(ic, http_transform, defaultHttpCycles, network, rpcUrl, rawTxHex)
  };

  public shared ({ caller }) func wallet_eth_address() : async EthAddressResult {
    assertOwner(caller);
    await WalletEvm.ethAddress(ic00, caller, Principal.fromActor(OpenClawOnICP))
  };

  public shared ({ caller }) func wallet_send_eth(network : Text, rpcUrl : ?Text, toAddress : Text, amountWei : Nat) : async SendEthResult {
    assertOwner(caller);
    await WalletEvm.send(
      ic,
      http_transform,
      defaultHttpCycles,
      ic00,
      caller,
      Principal.fromActor(OpenClawOnICP),
      network,
      rpcUrl,
      toAddress,
      amountWei,
    )
  };

  public shared ({ caller }) func wallet_send_erc20(network : Text, rpcUrl : ?Text, tokenAddress : Text, toAddress : Text, amount : Nat) : async SendEthResult {
    assertOwner(caller);
    await WalletEvm.sendErc20(
      ic,
      http_transform,
      defaultHttpCycles,
      ic00,
      caller,
      Principal.fromActor(OpenClawOnICP),
      network,
      rpcUrl,
      tokenAddress,
      toAddress,
      amount,
    )
  };

  public shared ({ caller }) func wallet_buy_cketh_one(maxIcpE8s : Nat64) : async BuyCkEthResult {
    assertOwner(caller);
    if (maxIcpE8s == 0) return #err("maxIcpE8s must be > 0");
    await CkEthTrade.buyOne(ckethVenueConfig(), maxIcpE8s)
  };

  public shared ({ caller }) func wallet_buy_cketh(amountCkEthText : Text, maxIcpE8s : Nat64) : async BuyCkEthResult {
    assertOwner(caller);
    if (maxIcpE8s == 0) return #err("maxIcpE8s must be > 0");
    await CkEthTrade.buyBest(ckethVenueConfig(), amountCkEthText, maxIcpE8s)
  };

  public shared ({ caller }) func wallet_balance_eth(network : Text, rpcUrl : ?Text) : async BalanceResult {
    assertOwner(caller);
    await WalletEvm.balanceEth(
      ic,
      http_transform,
      defaultHttpCycles,
      ic00,
      caller,
      Principal.fromActor(OpenClawOnICP),
      network,
      rpcUrl,
    )
  };

  public shared ({ caller }) func wallet_balance_erc20(network : Text, rpcUrl : ?Text, tokenAddress : Text) : async BalanceResult {
    assertOwner(caller);
    await WalletEvm.balanceErc20(
      ic,
      http_transform,
      defaultHttpCycles,
      ic00,
      caller,
      Principal.fromActor(OpenClawOnICP),
      network,
      rpcUrl,
      tokenAddress,
    )
  };

  // -----------------------------
  // sessions_* (openclaw-like)
  // -----------------------------

  public shared ({ caller }) func sessions_create(sessionId : Text) : async () {
    assertOwner(caller);
    Sessions.create(users, caller, sessionId, nowNs);
  };

  public shared ({ caller }) func sessions_reset(sessionId : Text) : async () {
    assertOwner(caller);
    Sessions.reset(users, caller, sessionId, nowNs);
  };

  public shared query ({ caller }) func sessions_list_for(principal : Principal) : async [SessionSummary] {
    assertOwnerQuery(caller);
    switch (users.get(principal)) {
      case null [];
      case (?u) Sessions.list(u);
    }
  };

  public shared ({ caller }) func sessions_list() : async [SessionSummary] {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Sessions.list(u)
  };

  public shared ({ caller }) func sessions_history(sessionId : Text, limit : Nat) : async [ChatMessage] {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Sessions.history(u, sessionId, limit, nowNs)
  };

  transient let defaultHttpCycles : Nat = 30_000_000_000;

  // Model discovery (for UI dropdowns)
  public shared ({ caller }) func models_list(provider : Provider, apiKey : Text) : async ModelsResult {
    assertOwner(caller);
    let resolvedApiKey = switch (resolveApiKey(provider, apiKey)) {
      case (#err(e)) return #err(e);
      case (#ok(k)) k;
    };
    await Llm.listModels(ic, http_transform, defaultHttpCycles, provider, resolvedApiKey)
  };

  func modelCaller(
    provider : Provider,
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [ChatMessage],
    toolSpecs : [Sessions.ToolSpec],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) : async Result.Result<Text, Text> {
    await Llm.callModel(
      ic,
      http_transform,
      defaultHttpCycles,
      provider,
      model,
      apiKey,
      sysPrompt,
      history,
      toolSpecs,
      maxTokens,
      temperature,
    )
  };

  let llmToolSpecs : [Sessions.ToolSpec] = LlmToolRouter.defaultSpecs;

  func toolCaller(name : Text, args : [Text]) : async ToolResult {
    await LlmToolRouter.dispatch(
      name,
      args,
      func(toPrincipalText : Text, amountE8s : Nat64) : async Result.Result<Nat, Text> {
        await WalletIcp.sendIcp(icpLedgerLocalPrincipal, icpLedgerMainnetPrincipal, toPrincipalText, amountE8s)
      },
      func(network : Text, toAddress : Text, amountWei : Nat) : async Result.Result<Text, Text> {
        await WalletEvm.send(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          Principal.fromActor(OpenClawOnICP),
          Principal.fromActor(OpenClawOnICP),
          network,
          null,
          toAddress,
          amountWei,
        )
      },
      func(chatId : Nat, messageText : Text) : async Result.Result<(), Text> {
        let token = switch (tgBotToken) {
          case null return #err("telegram bot token not configured");
          case (?t) t;
        };
        await Telegram.sendMessage(ic, http_transform, defaultHttpCycles, token, chatId, messageText)
      },
      func(amountCkEthText : Text, maxIcpE8s : Nat64) : async Result.Result<Text, Text> {
        await CkEthTrade.buyBest(ckethVenueConfig(), amountCkEthText, maxIcpE8s)
      },
    )
  };
  public shared ({ caller }) func sessions_send(sessionId : Text, message : Text, opts : SendOptions) : async SendResult {
    assertOwner(caller);
    let resolvedApiKey = switch (resolveApiKey(opts.provider, opts.apiKey)) {
      case (#err(e)) return #err(e);
      case (#ok(k)) k;
    };
    let opts2 : SendOptions = {
      provider = opts.provider;
      model = opts.model;
      apiKey = resolvedApiKey;
      systemPrompt = opts.systemPrompt;
      maxTokens = opts.maxTokens;
      temperature = opts.temperature;
      skillNames = opts.skillNames;
      includeHistory = opts.includeHistory;
    };
    await Sessions.send(users, caller, sessionId, message, opts2, nowNs, modelCaller, ?toolCaller, llmToolSpecs)
  };

  // -----------------------------
  // skills_* (ClawHub-like, minimal)
  // -----------------------------

  public shared ({ caller }) func skills_put(name : Text, markdown : Text) : async () {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Skills.put(u, name, markdown, nowNs);
  };

  public shared ({ caller }) func skills_get(name : Text) : async ?Text {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Skills.get(u, name)
  };

  public shared ({ caller }) func skills_list() : async [Text] {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Skills.list(u)
  };

  public shared ({ caller }) func skills_delete(name : Text) : async Bool {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Skills.delete(u, name)
  };

  // -----------------------------
  // tools_* (very limited, chain-safe)
  // -----------------------------

  public shared ({ caller }) func hooks_list() : async [HookEntry] {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Hooks.list(u)
  };

  public shared ({ caller }) func hooks_put_command_reply(name : Text, command : Text, reply : Text) : async Bool {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Hooks.putCommandReply(u, name, command, reply)
  };

  public shared ({ caller }) func hooks_put_message_reply(name : Text, keyword : Text, reply : Text) : async Bool {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Hooks.putMessageReply(u, name, keyword, reply)
  };

  public shared ({ caller }) func hooks_put_command_tool(name : Text, command : Text, toolName : Text, toolArgs : [Text]) : async Bool {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Hooks.putCommandTool(u, name, command, toolName, toolArgs)
  };

  public shared ({ caller }) func hooks_put_message_tool(name : Text, keyword : Text, toolName : Text, toolArgs : [Text]) : async Bool {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Hooks.putMessageTool(u, name, keyword, toolName, toolArgs)
  };

  public shared ({ caller }) func hooks_delete(name : Text) : async Bool {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Hooks.delete(u, name)
  };

  public shared ({ caller }) func hooks_set_enabled(name : Text, enabled : Bool) : async Bool {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Hooks.setEnabled(u, name, enabled)
  };

  public shared ({ caller }) func tools_list() : async [Text] {
    assertOwner(caller);
    Tools.list()
  };

  public shared ({ caller }) func tools_invoke(name : Text, args : [Text]) : async ToolResult {
    assertOwner(caller);
    let u = Store.getOrInitUser(users, caller);
    Tools.invoke(u, name, args, nowNs)
  };
};
