import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import HttpTypes "./agentonicp/http/HttpTypes";
import ChannelRouter "./agentonicp/channels/ChannelRouter";
import Llm "./agentonicp/llm/Llm";
import Sessions "./agentonicp/core/Sessions";
import Hooks "./agentonicp/core/Hooks";
import Store "./agentonicp/core/Store";
import Telegram "./agentonicp/telegram/Telegram";
import Types "./agentonicp/core/Types";
import Wallet "./agentonicp/wallet/Wallet";
import WalletIcp "./agentonicp/wallet/WalletIcp";
import WalletEvm "./agentonicp/wallet/WalletEvm";
import RpcConfig "./agentonicp/wallet/RpcConfig";
import PolymarketResearch "./agentonicp/polymarket/PolymarketResearch";
import KeyVault "./agentonicp/core/KeyVault";
import AppConfig "./agentonicp/core/AppConfig";
import HooksMethods "./agentonicp/gateway/server-methods/HooksMethods";
import AdminMethods "./agentonicp/gateway/server-methods/AdminMethods";
import ModelsMethods "./agentonicp/gateway/server-methods/ModelsMethods";
import SessionsMethods "./agentonicp/gateway/server-methods/SessionsMethods";
import SkillsMethods "./agentonicp/gateway/server-methods/SkillsMethods";
import ToolsMethods "./agentonicp/gateway/server-methods/ToolsMethods";
import WalletApiMethods "./agentonicp/gateway/server-methods/WalletApiMethods";
import WalletFacadeMethods "./agentonicp/gateway/server-methods/WalletFacadeMethods";
import ChannelsMethods "./agentonicp/gateway/server-methods/ChannelsMethods";
import AuthContext "./agentonicp/gateway/context/AuthContext";
import GatewayRuntime "./agentonicp/gateway/runtime/GatewayRuntime";
import Migration "migration";

persistent actor AgentOnICP {
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
  public type LlmTrace = {
    id : Nat;
    tsNs : Int;
    provider : Text;
    model : Text;
    url : Text;
    requestBody : Text;
    responseBody : ?Text;
    error : ?Text;
  };

  public type ModelsResult = Result.Result<[Text], Text>;
  public type SendIcpResult = Result.Result<Nat, Text>;
  public type SendIcrc1Result = Result.Result<Nat, Text>;
  public type SendEthResult = Result.Result<Text, Text>;
  public type EthAddressResult = Result.Result<Text, Text>;
  public type BalanceResult = Result.Result<Nat, Text>;
  public type WalletResult = Wallet.WalletResult;
  public type EcdsaPublicKeyResult = Wallet.EcdsaPublicKeyResult;
  public type SignWithEcdsaResult = Wallet.SignWithEcdsaResult;
  public type AgentWallet = Wallet.AgentWallet;
  public type EcdsaPublicKeyOut = Wallet.EcdsaPublicKeyOut;
  public type SignWithEcdsaOut = Wallet.SignWithEcdsaOut;
  public type WalletNetworkInfo = WalletFacadeMethods.WalletNetworkInfo;
  public type WalletBalanceItem = WalletFacadeMethods.WalletBalanceItem;
  public type WalletOverviewOut = WalletFacadeMethods.WalletOverviewOut;
  public type WalletOverviewResult = WalletFacadeMethods.WalletOverviewResult;
  public type WalletReceiveAddress = WalletFacadeMethods.WalletReceiveAddress;
  public type WalletAssetDetailOut = WalletFacadeMethods.WalletAssetDetailOut;
  public type WalletAssetDetailResult = WalletFacadeMethods.WalletAssetDetailResult;
  public type WalletSendKind = WalletFacadeMethods.WalletSendKind;
  public type WalletSendRequest = WalletFacadeMethods.WalletSendRequest;
  public type WalletSendOut = WalletFacadeMethods.WalletSendOut;
  public type WalletSendActionResult = WalletFacadeMethods.WalletSendResult;
  public type WalletHistoryDirection = WalletFacadeMethods.WalletHistoryDirection;
  public type WalletHistoryItem = WalletFacadeMethods.WalletHistoryItem;
  public type WalletAssetHistoryResult = WalletFacadeMethods.WalletAssetHistoryResult;
  public type WalletIcrc1Token = WalletFacadeMethods.WalletIcrc1Token;
  public type WalletIcrc1TokenAddResult = WalletFacadeMethods.WalletIcrc1TokenAddResult;
  public type WalletEvmToken = WalletFacadeMethods.WalletEvmToken;
  public type WalletEvmTokenAddResult = WalletFacadeMethods.WalletEvmTokenAddResult;

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

  // -----------------------------
  // Minimal HTTP outcall interface
  // -----------------------------

  type HttpResponsePayload = HttpTypes.HttpResponsePayload;
  type TransformArgs = HttpTypes.TransformArgs;
  type HttpRequestArgs = HttpTypes.HttpRequestArgs;

  transient let ic : Llm.Http = actor ("aaaaa-aa");
  transient let ic00 : Wallet.Ic00 = actor ("aaaaa-aa");
  transient let icpLedgerMainnetPrincipal : Principal = AppConfig.icpLedgerMainnetPrincipal();
  transient let icpLedgerLocalPrincipal : Principal = AppConfig.icpLedgerLocalPrincipal();

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
  // Deprecated stable fields kept for upgrade compatibility.
  var ckethIcpswapQuoteUrl : ?Text = null;
  var ckethKongswapQuoteUrl : ?Text = null;
  var ckethIcpswapBrokerCanisterText : ?Text = null;
  var ckethKongswapBrokerCanisterText : ?Text = null;
  var icpLedgerUseMainnet : Bool = AppConfig.defaultIcpLedgerUseMainnet();
  var walletIcrc1Tokens : [WalletIcrc1Token] = [];
  var walletEvmTokens : [WalletEvmToken] = [];
  var walletEvmHistory : [WalletHistoryItem] = [];
  var llmApiKeysEnc : [(Text, Text)] = [];
  var migrationState : ?Migration.State = null;
  transient let maxLlmTraceEntries : Nat = 200;
  transient var nextLlmTraceId : Nat = 1;
  transient var llmTraces = Buffer.Buffer<LlmTrace>(0);

  func isOwner(_caller : Principal) : Bool {
    if (not AppConfig.authEnabled()) {
      return true;
    };
    AuthContext.isOwner(owner, _caller)
  };

  func assertOwner(caller : Principal) {
    if (not AppConfig.authEnabled()) {
      return;
    };
    owner := AuthContext.assertOwner(owner, caller);
  };

  func assertOwnerQuery(caller : Principal) {
    if (not AppConfig.authEnabled()) {
      return;
    };
    AuthContext.assertOwnerQuery(owner, caller);
  };

  public shared query ({ caller }) func owner_get() : async ?Principal {
    ignore authPrincipalFromQuery(caller);
    if (AppConfig.authEnabled()) {
      owner
    } else {
      ?selfPrincipal()
    }
  };

  public shared ({ caller }) func admin_set_tg(botToken : Text, secretToken : ?Text) : async () {
    let authPrincipal = authPrincipalFromUpdate(caller);
    AdminMethods.setTg(
      ownerGuardFor(caller),
      authPrincipal,
      botToken,
      secretToken,
      func(nextBotToken : ?Text, nextSecretToken : ?Text) {
        tgBotToken := nextBotToken;
        tgSecretToken := nextSecretToken;
      },
    );
  };

  public shared ({ caller }) func admin_set_llm_opts(opts : SendOptions) : async () {
    let authPrincipal = authPrincipalFromUpdate(caller);
    AdminMethods.setLlmOpts(
      ownerGuardFor(caller),
      authPrincipal,
      opts,
      func(nextOpts : ?SendOptions) {
        tgLlmOpts := nextOpts;
      },
    );
  };

  public shared ({ caller }) func admin_set_discord(proxySecret : ?Text) : async () {
    let authPrincipal = authPrincipalFromUpdate(caller);
    AdminMethods.setDiscord(
      ownerGuardFor(caller),
      authPrincipal,
      proxySecret,
      func(nextProxySecret : ?Text) {
        discordProxySecret := nextProxySecret;
      },
    );
  };

  public shared ({ caller }) func admin_set_provider_api_key(provider : Provider, apiKey : Text) : async () {
    let authPrincipal = authPrincipalFromUpdate(caller);
    AdminMethods.setProviderApiKey(
      ownerGuardFor(caller),
      authPrincipal,
      provider,
      apiKey,
      func(p : Provider, k : Text) {
        llmApiKeysEnc := KeyVault.setProviderApiKey(llmApiKeysEnc, p, k);
      },
    );
  };

  public shared query ({ caller }) func admin_has_provider_api_key(provider : Provider) : async Bool {
    let authPrincipal = authPrincipalFromQuery(caller);
    AdminMethods.hasProviderApiKey(
      ownerQueryGuardFor(caller),
      authPrincipal,
      provider,
      func(p : Provider) : Bool {
        KeyVault.hasProviderApiKey(llmApiKeysEnc, p)
      },
    )
  };

  func resolveApiKey(provider : Provider, providedApiKey : Text) : Result.Result<Text, Text> {
    KeyVault.resolveApiKey(llmApiKeysEnc, provider, providedApiKey)
  };

  func resolveApiKeyForPrincipal(caller : Principal, provider : Provider, providedApiKey : Text) : Result.Result<Text, Text> {
    if (not AppConfig.authEnabled()) {
      return resolveApiKey(provider, providedApiKey);
    };
    AuthContext.resolveApiKeyForCaller(owner, caller, provider, providedApiKey, resolveApiKey)
  };

  func selfPrincipal() : Principal {
    Principal.fromActor(AgentOnICP)
  };

  func ownerGuardFor(authCaller : Principal) : (caller : Principal) -> () {
    func(_ : Principal) { assertOwner(authCaller) }
  };

  func ownerQueryGuardFor(authCaller : Principal) : (caller : Principal) -> () {
    func(_ : Principal) { assertOwnerQuery(authCaller) }
  };

  func isOwnerGuardFor(authCaller : Principal) : (caller : Principal) -> Bool {
    func(_ : Principal) : Bool { isOwner(authCaller) }
  };

  func authPrincipalFromUpdate(caller : Principal) : Principal {
    assertOwner(caller);
    selfPrincipal()
  };

  func authPrincipalFromQuery(caller : Principal) : Principal {
    assertOwnerQuery(caller);
    selfPrincipal()
  };

  func providerText(provider : Provider) : Text {
    switch (provider) {
      case (#openai) "openai";
      case (#anthropic) "anthropic";
      case (#google) "google";
    }
  };

  func providerUrl(provider : Provider, model : Text) : Text {
    switch (provider) {
      case (#openai) "https://api.openai.com/v1/chat/completions";
      case (#anthropic) "https://api.anthropic.com/v1/messages";
      case (#google) "https://generativelanguage.googleapis.com/v1beta/models/" # model # ":generateContent";
    }
  };

  func appendLlmTrace(provider : Provider, model : Text, requestBody : Text, res : Result.Result<Text, Text>) {
    let id = nextLlmTraceId;
    nextLlmTraceId += 1;
    let trace : LlmTrace = switch (res) {
      case (#ok(raw)) {
        {
          id;
          tsNs = nowNs();
          provider = providerText(provider);
          model;
          url = providerUrl(provider, model);
          requestBody;
          responseBody = ?raw;
          error = null;
        }
      };
      case (#err(e)) {
        {
          id;
          tsNs = nowNs();
          provider = providerText(provider);
          model;
          url = providerUrl(provider, model);
          requestBody;
          responseBody = null;
          error = ?e;
        }
      };
    };
    if (llmTraces.size() >= maxLlmTraceEntries) {
      ignore llmTraces.remove(0);
    };
    llmTraces.add(trace);
  };

  func sessionsMethodsDeps(authCaller : Principal) : SessionsMethods.Deps {
    {
      users = users;
      nowNs = nowNs;
      assertAuthenticated = ownerGuardFor(authCaller);
      assertOwnerQuery = ownerQueryGuardFor(authCaller);
      isOwner = isOwnerGuardFor(authCaller);
      resolveApiKeyForCaller = func(_ : Principal, provider : Provider, providedApiKey : Text) : Result.Result<Text, Text> {
        resolveApiKeyForPrincipal(authCaller, provider, providedApiKey)
      };
      modelCaller = func(
        provider : Provider,
        model : Text,
        apiKey : Text,
        sysPrompt : Text,
        history : [ChatMessage],
        toolSpecs : [Sessions.ToolSpec],
        maxTokens : ?Nat,
        temperature : ?Float,
      ) : async Result.Result<Text, Text> {
        await GatewayRuntime.modelCaller(runtimeDeps(), provider, model, apiKey, sysPrompt, history, toolSpecs, maxTokens, temperature)
      };
      llmToolSpecsFor = func(sessionId : Text, includeOwnerTools : Bool) : [Sessions.ToolSpec] {
        GatewayRuntime.llmToolSpecsFor(sessionId, includeOwnerTools)
      };
      llmToolCallerFor = func(callerPrincipal : Principal, sessionId : Text, includeOwnerTools : Bool) : Sessions.ToolCaller {
        GatewayRuntime.llmToolCallerFor(runtimeDeps(), callerPrincipal, sessionId, includeOwnerTools)
      };
    }
  };

  func modelsMethodsDeps(authCaller : Principal) : ModelsMethods.Deps {
    {
      ic = ic;
      transformFn = http_transform;
      defaultHttpCycles = defaultHttpCycles;
      assertAuthenticated = ownerGuardFor(authCaller);
      resolveApiKeyForCaller = func(_ : Principal, provider : Provider, providedApiKey : Text) : Result.Result<Text, Text> {
        resolveApiKeyForPrincipal(authCaller, provider, providedApiKey)
      };
    }
  };

  func skillsMethodsDeps(authCaller : Principal) : SkillsMethods.Deps {
    {
      users = users;
      nowNs = nowNs;
      assertAuthenticated = ownerGuardFor(authCaller);
    }
  };

  func hooksMethodsDeps(authCaller : Principal) : HooksMethods.Deps {
    {
      users = users;
      assertAuthenticated = ownerGuardFor(authCaller);
    }
  };

  func toolsMethodsDeps(authCaller : Principal) : ToolsMethods.Deps {
    {
      assertAuthenticated = ownerGuardFor(authCaller);
      isOwner = isOwnerGuardFor(authCaller);
      apiToolCallerFor = func(callerPrincipal : Principal, includeOwnerTools : Bool) : Sessions.ToolCaller {
        GatewayRuntime.apiToolCallerFor(runtimeDeps(), callerPrincipal, includeOwnerTools)
      };
    }
  };

  func channelsMethodsDeps() : ChannelsMethods.Deps {
    {
      tgLlmOpts = tgLlmOpts;
      resolveApiKey = resolveApiKey;
      llmToolCallerFor = func(callerPrincipal : Principal, sessionId : Text, includeOwnerTools : Bool) : Sessions.ToolCaller {
        GatewayRuntime.llmToolCallerFor(runtimeDeps(), callerPrincipal, sessionId, includeOwnerTools)
      };
      llmToolSpecsFor = func(sessionId : Text, includeOwnerTools : Bool) : [Sessions.ToolSpec] {
        GatewayRuntime.llmToolSpecsFor(sessionId, includeOwnerTools)
      };
      users = users;
      canisterPrincipal = selfPrincipal();
      nowNs = nowNs;
      modelCaller = func(
        provider : Provider,
        model : Text,
        apiKey : Text,
        sysPrompt : Text,
        history : [ChatMessage],
        toolSpecs : [Sessions.ToolSpec],
        maxTokens : ?Nat,
        temperature : ?Float,
      ) : async Result.Result<Text, Text> {
        await GatewayRuntime.modelCaller(runtimeDeps(), provider, model, apiKey, sysPrompt, history, toolSpecs, maxTokens, temperature)
      };
      tgBotToken = tgBotToken;
      tgSecretToken = tgSecretToken;
      discordProxySecret = discordProxySecret;
      ic = ic;
      transformFn = http_transform;
      defaultHttpCycles = defaultHttpCycles;
    }
  };

  func runtimeDeps() : GatewayRuntime.Deps {
    {
      users = users;
      nowNs = nowNs;
      callModel = func(
        provider : Provider,
        model : Text,
        apiKey : Text,
        sysPrompt : Text,
        history : [ChatMessage],
        toolSpecs : [Sessions.ToolSpec],
        maxTokens : ?Nat,
        temperature : ?Float,
      ) : async Result.Result<Text, Text> {
        let preview = Llm.previewRequest(
          provider,
          model,
          apiKey,
          sysPrompt,
          history,
          toolSpecs,
          maxTokens,
          temperature,
        );
        let res = await Llm.callModel(
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
        );
        appendLlmTrace(provider, model, preview.body, res);
        res
      };
      sendIcp = func(toPrincipalText : Text, amountE8s : Nat64) : async Result.Result<Nat, Text> {
        let ledgerPrincipal = effectiveIcpLedgerPrincipal();
        await WalletIcp.sendIcp(ledgerPrincipal, ledgerPrincipal, toPrincipalText, amountE8s)
      };
      sendEth = func(network : Text, toAddress : Text, amountWei : Nat) : async Result.Result<Text, Text> {
        await WalletEvm.send(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          selfPrincipal(),
          selfPrincipal(),
          network,
          effectiveRpcUrl(network, null),
          toAddress,
          amountWei,
        )
      };
      sendErc20 = func(
        network : Text,
        tokenAddress : Text,
        toAddress : Text,
        amount : Nat,
      ) : async Result.Result<Text, Text> {
        await WalletEvm.sendErc20(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          selfPrincipal(),
          selfPrincipal(),
          network,
          effectiveRpcUrl(network, null),
          tokenAddress,
          toAddress,
          amount,
        )
      };
      buyErc20Uniswap = func(
        network : Text,
        routerAddress : Text,
        tokenInAddress : Text,
        tokenOutAddress : Text,
        fee : Nat,
        amountIn : Nat,
        amountOutMinimum : Nat,
        deadline : Nat,
        sqrtPriceLimitX96 : Nat,
      ) : async Result.Result<Text, Text> {
        await WalletEvm.buyErc20Uniswap(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          selfPrincipal(),
          selfPrincipal(),
          network,
          effectiveRpcUrl(network, null),
          routerAddress,
          tokenInAddress,
          tokenOutAddress,
          fee,
          amountIn,
          amountOutMinimum,
          deadline,
          sqrtPriceLimitX96,
        )
      };
      swapErc20Uniswap = func(
        network : Text,
        routerAddress : Text,
        tokenInAddress : Text,
        tokenOutAddress : Text,
        fee : Nat,
        amountIn : Nat,
        amountOutMinimum : Nat,
        deadline : Nat,
        sqrtPriceLimitX96 : Nat,
        autoApprove : Bool,
      ) : async Result.Result<Text, Text> {
        await WalletEvm.swapErc20Uniswap(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          selfPrincipal(),
          selfPrincipal(),
          network,
          effectiveRpcUrl(network, null),
          routerAddress,
          tokenInAddress,
          tokenOutAddress,
          fee,
          amountIn,
          amountOutMinimum,
          deadline,
          sqrtPriceLimitX96,
          autoApprove,
        )
      };
      buyUni = func(
        network : Text,
        amountUniBase : Nat,
        slippageBps : Nat,
        deadline : Nat,
      ) : async Result.Result<Text, Text> {
        await WalletEvm.buyUniAuto(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          selfPrincipal(),
          selfPrincipal(),
          network,
          effectiveRpcUrl(network, null),
          amountUniBase,
          slippageBps,
          deadline,
        )
      };
      polymarketResearch = func(
        topic : Text,
        marketLimit : Nat,
        newsLimit : Nat,
      ) : async Result.Result<Text, Text> {
        await PolymarketResearch.research(
          ic,
          http_transform,
          defaultHttpCycles,
          topic,
          marketLimit,
          newsLimit,
        )
      };
      sendTg = func(chatId : Nat, messageText : Text) : async Result.Result<(), Text> {
        let token = switch (tgBotToken) {
          case null return #err("telegram bot token not configured");
          case (?t) t;
        };
        await Telegram.sendMessage(ic, http_transform, defaultHttpCycles, token, chatId, messageText)
      };
    }
  };

  public shared ({ caller }) func admin_tg_set_webhook(webhookUrl : Text) : async Result.Result<Text, Text> {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await AdminMethods.tgSetWebhook(
      ownerGuardFor(caller),
      authPrincipal,
      webhookUrl,
      func() : ?Text { tgBotToken },
      func() : ?Text { tgSecretToken },
      func(token : Text, url : Text, secret : ?Text) : async Result.Result<Text, Text> {
        await Telegram.setWebhook(ic, http_transform, defaultHttpCycles, token, url, secret)
      },
    )
  };

  public shared query ({ caller }) func tg_status() : async TgStatus {
    let authPrincipal = authPrincipalFromQuery(caller);
    AdminMethods.tgStatus(
      ownerQueryGuardFor(caller),
      authPrincipal,
      func() : ?Text { tgBotToken },
      func() : ?Text { tgSecretToken },
      func() : ?SendOptions { tgLlmOpts },
    )
  };

  public shared query ({ caller }) func discord_status() : async DiscordStatus {
    let authPrincipal = authPrincipalFromQuery(caller);
    AdminMethods.discordStatus(
      ownerQueryGuardFor(caller),
      authPrincipal,
      func() : ?Text { discordProxySecret },
      func() : ?SendOptions { tgLlmOpts },
    )
  };

  // Canister HTTP entrypoint (query): upgrade Telegram webhooks to update.
  public query func http_request(req : InHttpRequest) : async InHttpResponse {
    ChannelsMethods.routeQuery(req)
  };

  // Canister HTTP update handler: process Telegram webhook.
  public shared ({ caller = _ }) func http_request_update(req : InHttpRequest) : async InHttpResponse {
    await ChannelsMethods.routeUpdate(req, channelsMethodsDeps())
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
      walletIcrc1Tokens,
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
        walletIcrc1Tokens := restored.walletIcrc1Tokens;
      };
      case null {
        // Keep persisted state as-is when there is no migration snapshot.
      };
    };
    users := Store.fromStore(usersStore);
  };

  func nowNs() : Int { Time.now() };

  func effectiveRpcUrl(network : Text, rpcUrl : ?Text) : ?Text {
    RpcConfig.effectiveRpcUrl(network, rpcUrl)
  };

  func effectiveIcpLedgerPrincipal() : Principal {
    if (icpLedgerUseMainnet) {
      icpLedgerMainnetPrincipal
    } else {
      icpLedgerLocalPrincipal
    }
  };

  func trimText(value : Text) : Text {
    Text.trim(value, #char ' ')
  };

  func normalizeWalletSymbol(symbol : Text) : Text {
    Text.toUppercase(trimText(symbol))
  };

  func isReservedWalletSymbol(symbolUpper : Text) : Bool {
    symbolUpper == "ICP" or symbolUpper == "ETH" or symbolUpper == "SOL" or symbolUpper == "ERC20"
  };

  func symbolExists(symbolUpper : Text, ignoreLedgerPrincipalText : ?Text) : Bool {
    label scan for (token in walletIcrc1Tokens.vals()) {
      if (switch (ignoreLedgerPrincipalText) {
        case null false;
        case (?ledger) token.ledgerPrincipalText == ledger;
      }) {
        continue scan;
      };
      if (normalizeWalletSymbol(token.symbol) == symbolUpper) {
        return true;
      };
    };
    false
  };

  func uniqueWalletSymbol(baseSymbol : Text, ignoreLedgerPrincipalText : ?Text) : Text {
    let seedRaw = trimText(baseSymbol);
    let seed = if (Text.size(seedRaw) == 0) {
      "ICRC1"
    } else {
      seedRaw
    };
    var candidate = seed;
    var nextSuffix : Nat = 2;
    label pick while (isReservedWalletSymbol(normalizeWalletSymbol(candidate)) or symbolExists(normalizeWalletSymbol(candidate), ignoreLedgerPrincipalText)) {
      candidate := seed # "-" # Nat.toText(nextSuffix);
      nextSuffix += 1;
    };
    candidate
  };

  func appendEvmHistory(network : Text, txHash : Text, toAddress : Text, amount : Nat, kind : Text) {
    let normalizedNetwork = RpcConfig.normalizeWalletNetwork(network);
    if (normalizedNetwork == "internet_computer" or normalizedNetwork == "solana") {
      return;
    };
    let tsRaw = nowNs();
    let tsNanos : Nat64 = if (tsRaw <= 0) {
      (0 : Nat64)
    } else {
      Nat64.fromNat(Int.abs(tsRaw))
    };
    let item : WalletHistoryItem = {
      network = normalizedNetwork;
      symbol = "ETH";
      blockIndex = 0;
      txHash;
      timestampNanos = tsNanos;
      direction = #outgoing;
      amount;
      fee = null;
      counterparty = ?toAddress;
      kind;
    };
    let maxItems : Nat = 500;
    let next = Buffer.Buffer<WalletHistoryItem>(maxItems);
    next.add(item);
    for (existing in walletEvmHistory.vals()) {
      if (next.size() >= maxItems) {
        return walletEvmHistory := Buffer.toArray(next);
      };
      next.add(existing);
    };
    walletEvmHistory := Buffer.toArray(next)
  };

  func evmAssetHistory(network : Text, symbol : Text, limit : Nat) : WalletAssetHistoryResult {
    let normalizedNetwork = RpcConfig.normalizeWalletNetwork(network);
    let normalizedSymbol = normalizeWalletSymbol(symbol);
    if (normalizedSymbol != "ETH") {
      return #ok([]);
    };
    let take = if (limit == 0) {
      50
    } else if (limit > 200) {
      200
    } else {
      limit
    };
    let out = Buffer.Buffer<WalletHistoryItem>(take);
    for (item in walletEvmHistory.vals()) {
      if (out.size() >= take) {
        return #ok(Buffer.toArray(out));
      };
      if (item.network == normalizedNetwork and normalizeWalletSymbol(item.symbol) == normalizedSymbol) {
        out.add(item);
      };
    };
    #ok(Buffer.toArray(out))
  };

  func walletApiDeps(authCaller : Principal) : WalletApiMethods.Deps {
    let ledgerPrincipal = effectiveIcpLedgerPrincipal();
    {
      assertOwner = ownerGuardFor(authCaller);
      assertOwnerQuery = ownerQueryGuardFor(authCaller);
      selfPrincipal = selfPrincipal;
      effectiveRpcUrl = effectiveRpcUrl;
      ic = ic;
      ic00 = ic00;
      httpTransform = http_transform;
      defaultHttpCycles = defaultHttpCycles;
      icpLedgerLocalPrincipal = ledgerPrincipal;
      icpLedgerMainnetPrincipal = ledgerPrincipal;
    }
  };

  func walletFacadeDeps(authCaller : Principal) : WalletFacadeMethods.Deps {
    let ledgerPrincipal = effectiveIcpLedgerPrincipal();
    {
      assertOwner = ownerGuardFor(authCaller);
      assertOwnerQuery = ownerQueryGuardFor(authCaller);
      selfPrincipal = selfPrincipal;
      effectiveRpcUrl = effectiveRpcUrl;
      ic = ic;
      ic00 = ic00;
      httpTransform = http_transform;
      defaultHttpCycles = defaultHttpCycles;
      icpLedgerLocalPrincipal = ledgerPrincipal;
      icpLedgerMainnetPrincipal = ledgerPrincipal;
      icpLedgerUseMainnet = icpLedgerUseMainnet;
      icrc1Tokens = walletIcrc1Tokens;
      evmTokens = walletEvmTokens;
    }
  };

  func normalizeWalletNetworkText(network : Text) : Text {
    RpcConfig.normalizeWalletNetwork(trimText(network))
  };

  func normalizeEvmTokenAddress(address : Text) : Text {
    Text.toLowercase(trimText(address))
  };

  func validEvmTokenAddress(address : Text) : Bool {
    let a = normalizeEvmTokenAddress(address);
    Text.size(a) == 42 and Text.startsWith(a, #text "0x")
  };

  public shared ({ caller }) func wallet_set_icp_ledger_mainnet(useMainnet : Bool) : async () {
    assertOwner(caller);
    icpLedgerUseMainnet := useMainnet;
  };

  public shared query ({ caller }) func wallet_get_icp_ledger_mainnet() : async Bool {
    assertOwnerQuery(caller);
    icpLedgerUseMainnet
  };

  public shared query ({ caller }) func wallet_icrc1_tokens() : async [WalletIcrc1Token] {
    assertOwnerQuery(caller);
    walletIcrc1Tokens
  };

  public shared query ({ caller }) func wallet_evm_tokens() : async [WalletEvmToken] {
    assertOwnerQuery(caller);
    walletEvmTokens
  };

  public shared ({ caller }) func wallet_icrc1_token_add(ledgerPrincipalText : Text) : async WalletIcrc1TokenAddResult {
    assertOwner(caller);
    let ledger = trimText(ledgerPrincipalText);
    if (Text.size(ledger) == 0) {
      return #err("ledger principal is required");
    };

    switch (await WalletIcp.icrc1Metadata(ledger)) {
      case (#err(e)) #err(e);
      case (#ok(meta)) {
        var existing : ?WalletIcrc1Token = null;
        label findExisting for (token in walletIcrc1Tokens.vals()) {
          if (token.ledgerPrincipalText == meta.ledgerPrincipalText) {
            existing := ?token;
            break findExisting;
          };
        };

        let symbol = switch (existing) {
          case null uniqueWalletSymbol(meta.symbol, null);
          case (?token) token.symbol;
        };
        let normalizedName = trimText(meta.name);
        let nextToken : WalletIcrc1Token = {
          symbol;
          name = if (Text.size(normalizedName) == 0) symbol else normalizedName;
          ledgerPrincipalText = meta.ledgerPrincipalText;
          decimals = meta.decimals;
        };

        switch (existing) {
          case null {
            walletIcrc1Tokens := Array.append<WalletIcrc1Token>(walletIcrc1Tokens, [nextToken]);
            #ok(nextToken)
          };
          case (?_) {
            let next = Buffer.Buffer<WalletIcrc1Token>(Array.size(walletIcrc1Tokens));
            for (token in walletIcrc1Tokens.vals()) {
              if (token.ledgerPrincipalText == meta.ledgerPrincipalText) {
                next.add(nextToken);
              } else {
                next.add(token);
              };
            };
            walletIcrc1Tokens := Buffer.toArray(next);
            #ok(nextToken)
          };
        }
      };
    }
  };

  public shared ({ caller }) func wallet_icrc1_token_remove(ledgerPrincipalText : Text) : async Bool {
    assertOwner(caller);
    let targetLedger = trimText(ledgerPrincipalText);
    if (Text.size(targetLedger) == 0) {
      return false;
    };
    let next = Buffer.Buffer<WalletIcrc1Token>(Array.size(walletIcrc1Tokens));
    var removed = false;
    for (token in walletIcrc1Tokens.vals()) {
      if (token.ledgerPrincipalText == targetLedger) {
        removed := true;
      } else {
        next.add(token);
      };
    };
    if (removed) {
      walletIcrc1Tokens := Buffer.toArray(next);
    };
    removed
  };

  public shared ({ caller }) func wallet_evm_token_add(
    network : Text,
    tokenAddress : Text,
    symbol : ?Text,
    name : ?Text,
    decimals : ?Nat,
  ) : async WalletEvmTokenAddResult {
    assertOwner(caller);
    let normalizedNetwork = normalizeWalletNetworkText(network);
    if (normalizedNetwork == "internet_computer" or normalizedNetwork == "solana" or RpcConfig.chainId(normalizedNetwork) == null) {
      return #err("network is not an EVM chain: " # network);
    };

    let normalizedAddress = normalizeEvmTokenAddress(tokenAddress);
    if (not validEvmTokenAddress(normalizedAddress)) {
      return #err("invalid EVM contract address");
    };

    let symbolText = switch (symbol) {
      case null "ERC20";
      case (?v) {
        let trimmed = trimText(v);
        if (Text.size(trimmed) == 0) "ERC20" else Text.toUppercase(trimmed)
      };
    };
    let nameText = switch (name) {
      case null "ERC20 Token";
      case (?v) {
        let trimmed = trimText(v);
        if (Text.size(trimmed) == 0) "ERC20 Token" else trimmed
      };
    };
    let decimalsValue = switch (decimals) {
      case null 18;
      case (?d) if (d > 36) 18 else d;
    };

    let token : WalletEvmToken = {
      network = normalizedNetwork;
      symbol = symbolText;
      name = nameText;
      tokenAddress = normalizedAddress;
      decimals = decimalsValue;
    };

    let next = Buffer.Buffer<WalletEvmToken>(Array.size(walletEvmTokens) + 1);
    var updated = false;
    for (existing in walletEvmTokens.vals()) {
      if (normalizeWalletNetworkText(existing.network) == normalizedNetwork and normalizeEvmTokenAddress(existing.tokenAddress) == normalizedAddress) {
        next.add(token);
        updated := true;
      } else {
        next.add(existing);
      };
    };
    if (not updated) {
      next.add(token);
    };
    walletEvmTokens := Buffer.toArray(next);
    #ok(token)
  };

  public shared ({ caller }) func wallet_evm_token_remove(network : Text, tokenAddress : Text) : async Bool {
    assertOwner(caller);
    let normalizedNetwork = normalizeWalletNetworkText(network);
    let normalizedAddress = normalizeEvmTokenAddress(tokenAddress);
    let next = Buffer.Buffer<WalletEvmToken>(Array.size(walletEvmTokens));
    var removed = false;
    for (existing in walletEvmTokens.vals()) {
      if (normalizeWalletNetworkText(existing.network) == normalizedNetwork and normalizeEvmTokenAddress(existing.tokenAddress) == normalizedAddress) {
        removed := true;
      } else {
        next.add(existing);
      };
    };
    if (removed) {
      walletEvmTokens := Buffer.toArray(next);
    };
    removed
  };

  public shared query ({ caller }) func wallet_networks() : async [WalletNetworkInfo] {
    let authPrincipal = authPrincipalFromQuery(caller);
    WalletFacadeMethods.networks(walletFacadeDeps(caller), authPrincipal)
  };

  public shared ({ caller }) func wallet_overview(
    network : Text,
    rpcUrl : ?Text,
    erc20TokenAddress : ?Text,
  ) : async WalletOverviewResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletFacadeMethods.overview(
      walletFacadeDeps(caller),
      authPrincipal,
      network,
      rpcUrl,
      erc20TokenAddress,
    )
  };

  public shared ({ caller }) func wallet_asset_detail(
    network : Text,
    symbol : Text,
    rpcUrl : ?Text,
    erc20TokenAddress : ?Text,
  ) : async WalletAssetDetailResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletFacadeMethods.assetDetail(
      walletFacadeDeps(caller),
      authPrincipal,
      network,
      symbol,
      rpcUrl,
      erc20TokenAddress,
    )
  };

  public shared ({ caller }) func wallet_send(req : WalletSendRequest) : async WalletSendActionResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    let result = await WalletFacadeMethods.send(walletFacadeDeps(caller), authPrincipal, req);
    switch (result) {
      case (#ok(ok)) {
        switch (req.kind) {
          case (#eth) {
            appendEvmHistory(ok.network, ok.txId, req.to, req.amount, "transfer");
          };
          case (_) {};
        };
        #ok(ok)
      };
      case (#err(e)) #err(e);
    }
  };

  public shared ({ caller }) func wallet_asset_history(
    network : Text,
    symbol : Text,
    limit : Nat,
  ) : async WalletAssetHistoryResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    let normalizedNetwork = RpcConfig.normalizeWalletNetwork(network);
    if (normalizedNetwork != "internet_computer" and normalizedNetwork != "solana") {
      return evmAssetHistory(normalizedNetwork, symbol, limit);
    };
    await WalletFacadeMethods.assetHistory(walletFacadeDeps(caller), authPrincipal, network, symbol, limit)
  };

  public shared ({ caller }) func whoami() : async Text {
    ignore authPrincipalFromUpdate(caller);
    if (AppConfig.authEnabled()) {
      switch (owner) {
        case (?o) Principal.toText(o);
        case null Principal.toText(selfPrincipal());
      }
    } else {
      Principal.toText(selfPrincipal())
    }
  };

  public shared ({ caller }) func ecdsa_public_key(derivationPath : [Blob], keyName : ?Text) : async EcdsaPublicKeyResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.ecdsaPublicKey(walletApiDeps(caller), authPrincipal, derivationPath, keyName)
  };

  public shared ({ caller }) func sign_with_ecdsa(messageHash : Blob, derivationPath : [Blob], keyName : ?Text) : async SignWithEcdsaResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.signWithEcdsa(walletApiDeps(caller), authPrincipal, messageHash, derivationPath, keyName)
  };

  public shared ({ caller }) func agent_wallet() : async WalletResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.agentWallet(walletApiDeps(caller), authPrincipal)
  };

  public shared query ({ caller }) func canister_principal() : async Principal {
    let authPrincipal = authPrincipalFromQuery(caller);
    WalletApiMethods.canisterPrincipal(walletApiDeps(caller), authPrincipal)
  };

  public shared ({ caller }) func wallet_send_icp(toPrincipalText : Text, amountE8s : Nat64) : async SendIcpResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.sendIcp(walletApiDeps(caller), authPrincipal, toPrincipalText, amountE8s)
  };

  public shared ({ caller }) func wallet_send_icrc1(ledgerPrincipalText : Text, toPrincipalText : Text, amount : Nat, fee : ?Nat) : async SendIcrc1Result {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.sendIcrc1(walletApiDeps(caller), authPrincipal, ledgerPrincipalText, toPrincipalText, amount, fee)
  };

  public shared ({ caller }) func wallet_balance_icp() : async BalanceResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.balanceIcp(walletApiDeps(caller), authPrincipal)
  };

  public shared ({ caller }) func wallet_balance_icrc1(ledgerPrincipalText : Text) : async BalanceResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.balanceIcrc1(walletApiDeps(caller), authPrincipal, ledgerPrincipalText)
  };

  public shared ({ caller }) func wallet_send_eth_raw(network : Text, rpcUrl : ?Text, rawTxHex : Text) : async SendEthResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.sendEthRaw(walletApiDeps(caller), authPrincipal, network, rpcUrl, rawTxHex)
  };

  public shared ({ caller }) func wallet_eth_address() : async EthAddressResult {
    ignore authPrincipalFromUpdate(caller);
    await WalletApiMethods.ethAddressForCanister(walletApiDeps(caller))
  };

  public shared ({ caller }) func wallet_send_eth(network : Text, rpcUrl : ?Text, toAddress : Text, amountWei : Nat) : async SendEthResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    let result = await WalletApiMethods.sendEth(walletApiDeps(caller), authPrincipal, network, rpcUrl, toAddress, amountWei);
    switch (result) {
      case (#ok(txHash)) {
        appendEvmHistory(network, txHash, toAddress, amountWei, "transfer");
        #ok(txHash)
      };
      case (#err(e)) #err(e);
    }
  };

  public shared ({ caller }) func wallet_send_erc20(network : Text, rpcUrl : ?Text, tokenAddress : Text, toAddress : Text, amount : Nat) : async SendEthResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.sendErc20(walletApiDeps(caller), authPrincipal, network, rpcUrl, tokenAddress, toAddress, amount)
  };

  public shared ({ caller }) func wallet_buy_erc20_uniswap(
    network : Text,
    rpcUrl : ?Text,
    routerAddress : Text,
    tokenInAddress : Text,
    tokenOutAddress : Text,
    fee : Nat,
    amountIn : Nat,
    amountOutMinimum : Nat,
    deadline : Nat,
    sqrtPriceLimitX96 : Nat,
  ) : async SendEthResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.buyErc20Uniswap(
      walletApiDeps(caller),
      authPrincipal,
      network,
      rpcUrl,
      routerAddress,
      tokenInAddress,
      tokenOutAddress,
      fee,
      amountIn,
      amountOutMinimum,
      deadline,
      sqrtPriceLimitX96,
    )
  };

  public shared ({ caller }) func wallet_swap_uniswap(
    network : Text,
    rpcUrl : ?Text,
    routerAddress : Text,
    tokenInAddress : Text,
    tokenOutAddress : Text,
    fee : Nat,
    amountIn : Nat,
    amountOutMinimum : Nat,
    deadline : Nat,
    sqrtPriceLimitX96 : Nat,
    autoApprove : Bool,
  ) : async SendEthResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.swapErc20Uniswap(
      walletApiDeps(caller),
      authPrincipal,
      network,
      rpcUrl,
      routerAddress,
      tokenInAddress,
      tokenOutAddress,
      fee,
      amountIn,
      amountOutMinimum,
      deadline,
      sqrtPriceLimitX96,
      autoApprove,
    )
  };

  public shared ({ caller }) func wallet_buy_uni(
    network : Text,
    rpcUrl : ?Text,
    amountUniBase : Nat,
    slippageBps : Nat,
    deadline : Nat,
  ) : async SendEthResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.buyUni(walletApiDeps(caller), authPrincipal, network, rpcUrl, amountUniBase, slippageBps, deadline)
  };

  public shared query ({ caller }) func wallet_token_address(network : Text, symbol : Text) : async ?Text {
    let authPrincipal = authPrincipalFromQuery(caller);
    WalletApiMethods.tokenAddress(walletApiDeps(caller), authPrincipal, network, symbol)
  };

  public shared ({ caller }) func polymarket_research(topic : Text, marketLimit : Nat, newsLimit : Nat) : async Result.Result<Text, Text> {
    assertOwner(caller);
    await PolymarketResearch.research(
      ic,
      http_transform,
      defaultHttpCycles,
      topic,
      marketLimit,
      newsLimit,
    )
  };

  public shared ({ caller }) func wallet_balance_eth(network : Text, rpcUrl : ?Text) : async BalanceResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.balanceEth(walletApiDeps(caller), authPrincipal, network, rpcUrl)
  };

  public shared ({ caller }) func wallet_balance_erc20(network : Text, rpcUrl : ?Text, tokenAddress : Text) : async BalanceResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await WalletApiMethods.balanceErc20(walletApiDeps(caller), authPrincipal, network, rpcUrl, tokenAddress)
  };

  // -----------------------------
  // sessions_* (openclaw-like)
  // -----------------------------

  public shared ({ caller }) func sessions_create(sessionId : Text) : async () {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SessionsMethods.create(sessionsMethodsDeps(caller), authPrincipal, sessionId);
  };

  public shared ({ caller }) func sessions_reset(sessionId : Text) : async () {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SessionsMethods.reset(sessionsMethodsDeps(caller), authPrincipal, sessionId);
  };

  public shared query ({ caller }) func sessions_list_for(principal : Principal) : async [SessionSummary] {
    let authPrincipal = authPrincipalFromQuery(caller);
    SessionsMethods.listFor(sessionsMethodsDeps(caller), authPrincipal, principal)
  };

  public shared ({ caller }) func sessions_list() : async [SessionSummary] {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SessionsMethods.list(sessionsMethodsDeps(caller), authPrincipal)
  };

  public shared ({ caller }) func sessions_history(sessionId : Text, limit : Nat) : async [ChatMessage] {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SessionsMethods.history(sessionsMethodsDeps(caller), authPrincipal, sessionId, limit)
  };

  transient let defaultHttpCycles : Nat = AppConfig.defaultHttpCycles();

  public shared query ({ caller = _ }) func app_is_dev_mode() : async Bool {
    AppConfig.isDevMode()
  };

  // Model discovery (for UI dropdowns)
  public shared ({ caller }) func models_list(provider : Provider, apiKey : Text) : async ModelsResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await ModelsMethods.list(modelsMethodsDeps(caller), authPrincipal, provider, apiKey)
  };
  public shared ({ caller }) func sessions_send(sessionId : Text, message : Text, opts : SendOptions) : async SendResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await SessionsMethods.send(sessionsMethodsDeps(caller), authPrincipal, sessionId, message, opts)
  };

  public shared query ({ caller }) func dev_llm_traces(afterId : Nat, limit : Nat) : async [LlmTrace] {
    assertOwnerQuery(caller);
    let take = if (limit == 0) 100 else if (limit > 500) 500 else limit;
    let out = Buffer.Buffer<LlmTrace>(take);
    var i : Nat = 0;
    let n = llmTraces.size();
    while (i < n and out.size() < take) {
      let trace = llmTraces.get(i);
      if (trace.id > afterId) {
        out.add(trace);
      };
      i += 1;
    };
    Buffer.toArray(out)
  };

  // -----------------------------
  // skills_* (ClawHub-like, minimal)
  // -----------------------------

  public shared ({ caller }) func skills_put(name : Text, markdown : Text) : async () {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SkillsMethods.put(skillsMethodsDeps(caller), authPrincipal, name, markdown);
  };

  public shared ({ caller }) func skills_get(name : Text) : async ?Text {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SkillsMethods.get(skillsMethodsDeps(caller), authPrincipal, name)
  };

  public shared ({ caller }) func skills_list() : async [Text] {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SkillsMethods.list(skillsMethodsDeps(caller), authPrincipal)
  };

  public shared ({ caller }) func skills_delete(name : Text) : async Bool {
    let authPrincipal = authPrincipalFromUpdate(caller);
    SkillsMethods.delete(skillsMethodsDeps(caller), authPrincipal, name)
  };

  // -----------------------------
  // hooks_* + tools_* (unified tool registry)
  // -----------------------------

  public shared ({ caller }) func hooks_list() : async [HookEntry] {
    let authPrincipal = authPrincipalFromUpdate(caller);
    HooksMethods.list(hooksMethodsDeps(caller), authPrincipal)
  };

  public shared ({ caller }) func hooks_put_command_reply(name : Text, command : Text, reply : Text) : async Bool {
    let authPrincipal = authPrincipalFromUpdate(caller);
    HooksMethods.putCommandReply(hooksMethodsDeps(caller), authPrincipal, name, command, reply)
  };

  public shared ({ caller }) func hooks_put_message_reply(name : Text, keyword : Text, reply : Text) : async Bool {
    let authPrincipal = authPrincipalFromUpdate(caller);
    HooksMethods.putMessageReply(hooksMethodsDeps(caller), authPrincipal, name, keyword, reply)
  };

  public shared ({ caller }) func hooks_put_command_tool(name : Text, command : Text, toolName : Text, toolArgs : [Text]) : async Bool {
    let authPrincipal = authPrincipalFromUpdate(caller);
    HooksMethods.putCommandTool(hooksMethodsDeps(caller), authPrincipal, name, command, toolName, toolArgs)
  };

  public shared ({ caller }) func hooks_put_message_tool(name : Text, keyword : Text, toolName : Text, toolArgs : [Text]) : async Bool {
    let authPrincipal = authPrincipalFromUpdate(caller);
    HooksMethods.putMessageTool(hooksMethodsDeps(caller), authPrincipal, name, keyword, toolName, toolArgs)
  };

  public shared ({ caller }) func hooks_delete(name : Text) : async Bool {
    let authPrincipal = authPrincipalFromUpdate(caller);
    HooksMethods.delete(hooksMethodsDeps(caller), authPrincipal, name)
  };

  public shared ({ caller }) func hooks_set_enabled(name : Text, enabled : Bool) : async Bool {
    let authPrincipal = authPrincipalFromUpdate(caller);
    HooksMethods.setEnabled(hooksMethodsDeps(caller), authPrincipal, name, enabled)
  };

  public shared ({ caller }) func tools_list() : async [Text] {
    let authPrincipal = authPrincipalFromUpdate(caller);
    ToolsMethods.list(toolsMethodsDeps(caller), authPrincipal)
  };

  public shared ({ caller }) func tools_invoke(name : Text, args : [Text]) : async ToolResult {
    let authPrincipal = authPrincipalFromUpdate(caller);
    await ToolsMethods.invoke(toolsMethodsDeps(caller), authPrincipal, name, args)
  };
};
