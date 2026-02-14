import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import HttpTypes "./openclaw/http/HttpTypes";
import ChannelRouter "./openclaw/channels/ChannelRouter";
import Llm "./openclaw/llm/Llm";
import Sessions "./openclaw/core/Sessions";
import Hooks "./openclaw/core/Hooks";
import Store "./openclaw/core/Store";
import Telegram "./openclaw/telegram/Telegram";
import Types "./openclaw/core/Types";
import Wallet "./openclaw/wallet/Wallet";
import WalletIcp "./openclaw/wallet/WalletIcp";
import WalletEvm "./openclaw/wallet/WalletEvm";
import RpcConfig "./openclaw/wallet/RpcConfig";
import TokenConfig "./openclaw/wallet/TokenConfig";
import CkEthTrade "./openclaw/wallet/CkEthTrade";
import PolymarketResearch "./openclaw/polymarket/PolymarketResearch";
import KeyVault "./openclaw/core/KeyVault";
import HooksMethods "./openclaw/gateway/server-methods/HooksMethods";
import AdminMethods "./openclaw/gateway/server-methods/AdminMethods";
import ModelsMethods "./openclaw/gateway/server-methods/ModelsMethods";
import SessionsMethods "./openclaw/gateway/server-methods/SessionsMethods";
import SkillsMethods "./openclaw/gateway/server-methods/SkillsMethods";
import ToolsMethods "./openclaw/gateway/server-methods/ToolsMethods";
import WalletMethods "./openclaw/gateway/server-methods/WalletMethods";
import ChannelsMethods "./openclaw/gateway/server-methods/ChannelsMethods";
import AuthContext "./openclaw/gateway/context/AuthContext";
import GatewayRuntime "./openclaw/gateway/runtime/GatewayRuntime";
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
  transient let maxLlmTraceEntries : Nat = 200;
  transient var nextLlmTraceId : Nat = 1;
  transient var llmTraces = Buffer.Buffer<LlmTrace>(0);

  func assertAuthenticated(caller : Principal) {
    AuthContext.assertAuthenticated(caller);
  };

  func isOwner(caller : Principal) : Bool {
    AuthContext.isOwner(owner, caller)
  };

  func assertOwner(caller : Principal) {
    owner := AuthContext.assertOwner(owner, caller);
  };

  func assertOwnerQuery(caller : Principal) {
    AuthContext.assertOwnerQuery(owner, caller);
  };

  public query func owner_get() : async ?Principal {
    owner
  };

  public shared ({ caller }) func admin_set_tg(botToken : Text, secretToken : ?Text) : async () {
    AdminMethods.setTg(
      assertOwner,
      caller,
      botToken,
      secretToken,
      func(nextBotToken : ?Text, nextSecretToken : ?Text) {
        tgBotToken := nextBotToken;
        tgSecretToken := nextSecretToken;
      },
    );
  };

  public shared ({ caller }) func admin_set_llm_opts(opts : SendOptions) : async () {
    AdminMethods.setLlmOpts(
      assertOwner,
      caller,
      opts,
      func(nextOpts : ?SendOptions) {
        tgLlmOpts := nextOpts;
      },
    );
  };

  public shared ({ caller }) func admin_set_discord(proxySecret : ?Text) : async () {
    AdminMethods.setDiscord(
      assertOwner,
      caller,
      proxySecret,
      func(nextProxySecret : ?Text) {
        discordProxySecret := nextProxySecret;
      },
    );
  };

  public shared ({ caller }) func admin_set_cketh_broker(canisterText : ?Text) : async () {
    AdminMethods.setCkethBroker(
      assertOwner,
      caller,
      canisterText,
      func(nextBroker : ?Text) {
        ckethIcpswapBrokerCanisterText := nextBroker;
      },
    );
  };

  public shared ({ caller }) func admin_set_cketh_brokers(icpswapCanisterText : ?Text, kongswapCanisterText : ?Text) : async () {
    AdminMethods.setCkethBrokers(
      assertOwner,
      caller,
      icpswapCanisterText,
      kongswapCanisterText,
      func(nextIcpswapBroker : ?Text, nextKongswapBroker : ?Text) {
        ckethIcpswapBrokerCanisterText := nextIcpswapBroker;
        ckethKongswapBrokerCanisterText := nextKongswapBroker;
      },
    );
  };

  public shared ({ caller }) func admin_set_cketh_quote_sources(icpswapQuoteUrl : ?Text, kongswapQuoteUrl : ?Text) : async () {
    AdminMethods.setCkethQuoteSources(
      assertOwner,
      caller,
      icpswapQuoteUrl,
      kongswapQuoteUrl,
      func(nextIcpswapQuoteUrl : ?Text, nextKongswapQuoteUrl : ?Text) {
        ckethIcpswapQuoteUrl := nextIcpswapQuoteUrl;
        ckethKongswapQuoteUrl := nextKongswapQuoteUrl;
      },
    );
  };

  public shared ({ caller }) func admin_set_provider_api_key(provider : Provider, apiKey : Text) : async () {
    AdminMethods.setProviderApiKey(
      assertOwner,
      caller,
      provider,
      apiKey,
      func(p : Provider, k : Text) {
        llmApiKeysEnc := KeyVault.setProviderApiKey(llmApiKeysEnc, p, k);
      },
    );
  };

  public shared query ({ caller }) func admin_has_provider_api_key(provider : Provider) : async Bool {
    AdminMethods.hasProviderApiKey(
      assertOwnerQuery,
      caller,
      provider,
      func(p : Provider) : Bool {
        KeyVault.hasProviderApiKey(llmApiKeysEnc, p)
      },
    )
  };

  func resolveApiKey(provider : Provider, providedApiKey : Text) : Result.Result<Text, Text> {
    KeyVault.resolveApiKey(llmApiKeysEnc, provider, providedApiKey)
  };

  func resolveApiKeyForCaller(caller : Principal, provider : Provider, providedApiKey : Text) : Result.Result<Text, Text> {
    AuthContext.resolveApiKeyForCaller(owner, caller, provider, providedApiKey, resolveApiKey)
  };

  func selfPrincipal() : Principal {
    Principal.fromActor(AgentOnICP)
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

  func sessionsMethodsDeps() : SessionsMethods.Deps {
    {
      users = users;
      nowNs = nowNs;
      assertAuthenticated = assertAuthenticated;
      assertOwnerQuery = assertOwnerQuery;
      isOwner = isOwner;
      resolveApiKeyForCaller = resolveApiKeyForCaller;
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

  func modelsMethodsDeps() : ModelsMethods.Deps {
    {
      ic = ic;
      transformFn = http_transform;
      defaultHttpCycles = defaultHttpCycles;
      assertAuthenticated = assertAuthenticated;
      resolveApiKeyForCaller = resolveApiKeyForCaller;
    }
  };

  func skillsMethodsDeps() : SkillsMethods.Deps {
    {
      users = users;
      nowNs = nowNs;
      assertAuthenticated = assertAuthenticated;
    }
  };

  func hooksMethodsDeps() : HooksMethods.Deps {
    {
      users = users;
      assertAuthenticated = assertAuthenticated;
    }
  };

  func toolsMethodsDeps() : ToolsMethods.Deps {
    {
      assertAuthenticated = assertAuthenticated;
      isOwner = isOwner;
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
        await WalletIcp.sendIcp(icpLedgerLocalPrincipal, icpLedgerMainnetPrincipal, toPrincipalText, amountE8s)
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
      buyCkEth = func(amountCkEthText : Text, maxIcpE8s : Nat64) : async Result.Result<Text, Text> {
        await CkEthTrade.buyBest(ckethVenueConfig(), amountCkEthText, maxIcpE8s)
      };
    }
  };

  public shared ({ caller }) func admin_tg_set_webhook(webhookUrl : Text) : async Result.Result<Text, Text> {
    await AdminMethods.tgSetWebhook(
      assertOwner,
      caller,
      webhookUrl,
      func() : ?Text { tgBotToken },
      func() : ?Text { tgSecretToken },
      func(token : Text, url : Text, secret : ?Text) : async Result.Result<Text, Text> {
        await Telegram.setWebhook(ic, http_transform, defaultHttpCycles, token, url, secret)
      },
    )
  };

  public shared ({ caller }) func tg_status() : async TgStatus {
    AdminMethods.tgStatus(
      assertOwner,
      caller,
      func() : ?Text { tgBotToken },
      func() : ?Text { tgSecretToken },
      func() : ?SendOptions { tgLlmOpts },
    )
  };

  public shared ({ caller }) func discord_status() : async DiscordStatus {
    AdminMethods.discordStatus(
      assertOwner,
      caller,
      func() : ?Text { discordProxySecret },
      func() : ?SendOptions { tgLlmOpts },
    )
  };

  public shared ({ caller }) func cketh_status() : async CkEthStatus {
    AdminMethods.ckethStatus(
      assertOwner,
      caller,
      func() : ?Text { ckethIcpswapQuoteUrl },
      func() : ?Text { ckethKongswapQuoteUrl },
      func() : ?Text { ckethIcpswapBrokerCanisterText },
      func() : ?Text { ckethKongswapBrokerCanisterText },
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

  func effectiveRpcUrl(network : Text, rpcUrl : ?Text) : ?Text {
    RpcConfig.effectiveRpcUrl(network, rpcUrl)
  };

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
    AdminMethods.whoami(assertOwner, caller)
  };

  public shared ({ caller }) func ecdsa_public_key(derivationPath : [Blob], keyName : ?Text) : async EcdsaPublicKeyResult {
    await WalletMethods.ecdsaPublicKey(
      assertOwner,
      caller,
      derivationPath,
      keyName,
      func(dp : [Blob], kn : ?Text) : async EcdsaPublicKeyResult {
        await WalletEvm.ecdsaPublicKey(ic00, caller, selfPrincipal(), dp, kn)
      },
    )
  };

  public shared ({ caller }) func sign_with_ecdsa(messageHash : Blob, derivationPath : [Blob], keyName : ?Text) : async SignWithEcdsaResult {
    await WalletMethods.signWithEcdsa(
      assertOwner,
      caller,
      messageHash,
      derivationPath,
      keyName,
      func(mh : Blob, dp : [Blob], kn : ?Text) : async SignWithEcdsaResult {
        await WalletEvm.signWithEcdsa(ic00, caller, mh, dp, kn)
      },
    )
  };

  public shared ({ caller }) func agent_wallet() : async WalletResult {
    await WalletMethods.agentWallet(
      assertOwner,
      caller,
      func() : async WalletResult {
        await WalletEvm.agentWallet(ic00, caller, selfPrincipal())
      },
    )
  };

  public shared query ({ caller }) func canister_principal() : async Principal {
    WalletMethods.canisterPrincipal(assertOwnerQuery, caller, selfPrincipal())
  };

  public shared ({ caller }) func wallet_send_icp(toPrincipalText : Text, amountE8s : Nat64) : async SendIcpResult {
    await WalletMethods.sendIcp(
      assertOwner,
      caller,
      toPrincipalText,
      amountE8s,
      func(toText : Text, amount : Nat64) : async SendIcpResult {
        await WalletIcp.sendIcp(icpLedgerLocalPrincipal, icpLedgerMainnetPrincipal, toText, amount)
      },
    )
  };

  public shared ({ caller }) func wallet_send_icrc1(ledgerPrincipalText : Text, toPrincipalText : Text, amount : Nat, fee : ?Nat) : async SendIcrc1Result {
    await WalletMethods.sendIcrc1(
      assertOwner,
      caller,
      ledgerPrincipalText,
      toPrincipalText,
      amount,
      fee,
      func(lp : Text, toText : Text, amt : Nat, maybeFee : ?Nat) : async SendIcrc1Result {
        await WalletIcp.sendIcrc1(lp, toText, amt, maybeFee)
      },
    )
  };

  public shared ({ caller }) func wallet_balance_icp() : async BalanceResult {
    await WalletMethods.balanceIcp(
      assertOwner,
      caller,
      func() : async BalanceResult {
        await WalletIcp.balanceIcp(icpLedgerLocalPrincipal, icpLedgerMainnetPrincipal, selfPrincipal())
      },
    )
  };

  public shared ({ caller }) func wallet_balance_icrc1(ledgerPrincipalText : Text) : async BalanceResult {
    await WalletMethods.balanceIcrc1(
      assertOwner,
      caller,
      ledgerPrincipalText,
      func(lp : Text) : async BalanceResult {
        await WalletIcp.balanceIcrc1(lp, selfPrincipal())
      },
    )
  };

  public shared ({ caller }) func wallet_send_eth_raw(network : Text, rpcUrl : ?Text, rawTxHex : Text) : async SendEthResult {
    await WalletMethods.sendEthRaw(
      assertOwner,
      caller,
      network,
      rpcUrl,
      rawTxHex,
      func(net : Text, url : ?Text, raw : Text) : async SendEthResult {
        await WalletEvm.sendRaw(ic, http_transform, defaultHttpCycles, net, effectiveRpcUrl(net, url), raw)
      },
    )
  };

  public shared ({ caller }) func wallet_eth_address() : async EthAddressResult {
    await WalletMethods.ethAddress(
      assertOwner,
      caller,
      func() : async EthAddressResult {
        await WalletEvm.ethAddress(ic00, caller, selfPrincipal())
      },
    )
  };

  public shared ({ caller }) func wallet_send_eth(network : Text, rpcUrl : ?Text, toAddress : Text, amountWei : Nat) : async SendEthResult {
    await WalletMethods.sendEth(
      assertOwner,
      caller,
      network,
      rpcUrl,
      toAddress,
      amountWei,
      func(net : Text, url : ?Text, to : Text, amount : Nat) : async SendEthResult {
        await WalletEvm.send(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          caller,
          selfPrincipal(),
          net,
          effectiveRpcUrl(net, url),
          to,
          amount,
        )
      },
    )
  };

  public shared ({ caller }) func wallet_send_erc20(network : Text, rpcUrl : ?Text, tokenAddress : Text, toAddress : Text, amount : Nat) : async SendEthResult {
    await WalletMethods.sendErc20(
      assertOwner,
      caller,
      network,
      rpcUrl,
      tokenAddress,
      toAddress,
      amount,
      func(net : Text, url : ?Text, token : Text, to : Text, amt : Nat) : async SendEthResult {
        await WalletEvm.sendErc20(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          caller,
          selfPrincipal(),
          net,
          effectiveRpcUrl(net, url),
          token,
          to,
          amt,
        )
      },
    )
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
    await WalletMethods.buyErc20Uniswap(
      assertOwner,
      caller,
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
      func(
        net : Text,
        url : ?Text,
        router : Text,
        tokenIn : Text,
        tokenOut : Text,
        poolFee : Nat,
        amountInBase : Nat,
        amountOutMinBase : Nat,
        deadlineSec : Nat,
        sqrtLimit : Nat,
      ) : async SendEthResult {
        await WalletEvm.buyErc20Uniswap(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          caller,
          selfPrincipal(),
          net,
          effectiveRpcUrl(net, url),
          router,
          tokenIn,
          tokenOut,
          poolFee,
          amountInBase,
          amountOutMinBase,
          deadlineSec,
          sqrtLimit,
        )
      },
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
    await WalletMethods.swapErc20Uniswap(
      assertOwner,
      caller,
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
      func(
        net : Text,
        url : ?Text,
        router : Text,
        tokenIn : Text,
        tokenOut : Text,
        poolFee : Nat,
        amountInBase : Nat,
        amountOutMinBase : Nat,
        deadlineSec : Nat,
        sqrtLimit : Nat,
        doAutoApprove : Bool,
      ) : async SendEthResult {
        await WalletEvm.swapErc20Uniswap(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          caller,
          selfPrincipal(),
          net,
          effectiveRpcUrl(net, url),
          router,
          tokenIn,
          tokenOut,
          poolFee,
          amountInBase,
          amountOutMinBase,
          deadlineSec,
          sqrtLimit,
          doAutoApprove,
        )
      },
    )
  };

  public shared ({ caller }) func wallet_buy_uni(
    network : Text,
    rpcUrl : ?Text,
    amountUniBase : Nat,
    slippageBps : Nat,
    deadline : Nat,
  ) : async SendEthResult {
    await WalletMethods.buyUniAuto(
      assertOwner,
      caller,
      network,
      rpcUrl,
      amountUniBase,
      slippageBps,
      deadline,
      func(
        net : Text,
        url : ?Text,
        amountUni : Nat,
        slippage : Nat,
        deadlineSec : Nat,
      ) : async SendEthResult {
        await WalletEvm.buyUniAuto(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          caller,
          selfPrincipal(),
          net,
          effectiveRpcUrl(net, url),
          amountUni,
          slippage,
          deadlineSec,
        )
      },
    )
  };

  public shared query ({ caller }) func wallet_token_address(network : Text, symbol : Text) : async ?Text {
    assertOwnerQuery(caller);
    TokenConfig.tokenAddress(network, symbol)
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

  public shared ({ caller }) func wallet_buy_cketh_one(maxIcpE8s : Nat64) : async BuyCkEthResult {
    await WalletMethods.buyCkEthOne(
      assertOwner,
      caller,
      maxIcpE8s,
      func(maxIcp : Nat64) : async BuyCkEthResult {
        await CkEthTrade.buyOne(ckethVenueConfig(), maxIcp)
      },
    )
  };

  public shared ({ caller }) func wallet_buy_cketh(amountCkEthText : Text, maxIcpE8s : Nat64) : async BuyCkEthResult {
    await WalletMethods.buyCkEth(
      assertOwner,
      caller,
      amountCkEthText,
      maxIcpE8s,
      func(amountText : Text, maxIcp : Nat64) : async BuyCkEthResult {
        await CkEthTrade.buyBest(ckethVenueConfig(), amountText, maxIcp)
      },
    )
  };

  public shared ({ caller }) func wallet_balance_eth(network : Text, rpcUrl : ?Text) : async BalanceResult {
    await WalletMethods.balanceEth(
      assertOwner,
      caller,
      network,
      rpcUrl,
      func(net : Text, url : ?Text) : async BalanceResult {
        await WalletEvm.balanceEth(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          caller,
          selfPrincipal(),
          net,
          effectiveRpcUrl(net, url),
        )
      },
    )
  };

  public shared ({ caller }) func wallet_balance_erc20(network : Text, rpcUrl : ?Text, tokenAddress : Text) : async BalanceResult {
    await WalletMethods.balanceErc20(
      assertOwner,
      caller,
      network,
      rpcUrl,
      tokenAddress,
      func(net : Text, url : ?Text, token : Text) : async BalanceResult {
        await WalletEvm.balanceErc20(
          ic,
          http_transform,
          defaultHttpCycles,
          ic00,
          caller,
          selfPrincipal(),
          net,
          effectiveRpcUrl(net, url),
          token,
        )
      },
    )
  };

  // -----------------------------
  // sessions_* (openclaw-like)
  // -----------------------------

  public shared ({ caller }) func sessions_create(sessionId : Text) : async () {
    SessionsMethods.create(sessionsMethodsDeps(), caller, sessionId);
  };

  public shared ({ caller }) func sessions_reset(sessionId : Text) : async () {
    SessionsMethods.reset(sessionsMethodsDeps(), caller, sessionId);
  };

  public shared query ({ caller }) func sessions_list_for(principal : Principal) : async [SessionSummary] {
    SessionsMethods.listFor(sessionsMethodsDeps(), caller, principal)
  };

  public shared ({ caller }) func sessions_list() : async [SessionSummary] {
    SessionsMethods.list(sessionsMethodsDeps(), caller)
  };

  public shared ({ caller }) func sessions_history(sessionId : Text, limit : Nat) : async [ChatMessage] {
    SessionsMethods.history(sessionsMethodsDeps(), caller, sessionId, limit)
  };

  transient let defaultHttpCycles : Nat = 30_000_000_000;

  // Model discovery (for UI dropdowns)
  public shared ({ caller }) func models_list(provider : Provider, apiKey : Text) : async ModelsResult {
    await ModelsMethods.list(modelsMethodsDeps(), caller, provider, apiKey)
  };
  public shared ({ caller }) func sessions_send(sessionId : Text, message : Text, opts : SendOptions) : async SendResult {
    await SessionsMethods.send(sessionsMethodsDeps(), caller, sessionId, message, opts)
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
    SkillsMethods.put(skillsMethodsDeps(), caller, name, markdown);
  };

  public shared ({ caller }) func skills_get(name : Text) : async ?Text {
    SkillsMethods.get(skillsMethodsDeps(), caller, name)
  };

  public shared ({ caller }) func skills_list() : async [Text] {
    SkillsMethods.list(skillsMethodsDeps(), caller)
  };

  public shared ({ caller }) func skills_delete(name : Text) : async Bool {
    SkillsMethods.delete(skillsMethodsDeps(), caller, name)
  };

  // -----------------------------
  // hooks_* + tools_* (unified tool registry)
  // -----------------------------

  public shared ({ caller }) func hooks_list() : async [HookEntry] {
    HooksMethods.list(hooksMethodsDeps(), caller)
  };

  public shared ({ caller }) func hooks_put_command_reply(name : Text, command : Text, reply : Text) : async Bool {
    HooksMethods.putCommandReply(hooksMethodsDeps(), caller, name, command, reply)
  };

  public shared ({ caller }) func hooks_put_message_reply(name : Text, keyword : Text, reply : Text) : async Bool {
    HooksMethods.putMessageReply(hooksMethodsDeps(), caller, name, keyword, reply)
  };

  public shared ({ caller }) func hooks_put_command_tool(name : Text, command : Text, toolName : Text, toolArgs : [Text]) : async Bool {
    HooksMethods.putCommandTool(hooksMethodsDeps(), caller, name, command, toolName, toolArgs)
  };

  public shared ({ caller }) func hooks_put_message_tool(name : Text, keyword : Text, toolName : Text, toolArgs : [Text]) : async Bool {
    HooksMethods.putMessageTool(hooksMethodsDeps(), caller, name, keyword, toolName, toolArgs)
  };

  public shared ({ caller }) func hooks_delete(name : Text) : async Bool {
    HooksMethods.delete(hooksMethodsDeps(), caller, name)
  };

  public shared ({ caller }) func hooks_set_enabled(name : Text, enabled : Bool) : async Bool {
    HooksMethods.setEnabled(hooksMethodsDeps(), caller, name, enabled)
  };

  public shared ({ caller }) func tools_list() : async [Text] {
    ToolsMethods.list(toolsMethodsDeps(), caller)
  };

  public shared ({ caller }) func tools_invoke(name : Text, args : [Text]) : async ToolResult {
    await ToolsMethods.invoke(toolsMethodsDeps(), caller, name, args)
  };
};
