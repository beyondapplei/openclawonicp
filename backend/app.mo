import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat16 "mo:base/Nat16";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import HttpTypes "./openclaw/HttpTypes";
import Llm "./openclaw/Llm";
import Sessions "./openclaw/Sessions";
import Skills "./openclaw/Skills";
import Store "./openclaw/Store";
import Tools "./openclaw/Tools";
import Telegram "./openclaw/Telegram";
import Types "./openclaw/Types";
import Wallet "./openclaw/Wallet";
import EthTx "./openclaw/EthTx";
import TokenTransfer "./openclaw/TokenTransfer";

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

  public type ModelsResult = Result.Result<[Text], Text>;
  public type SendIcpResult = Result.Result<Nat, Text>;
  public type SendIcrc1Result = Result.Result<Nat, Text>;
  public type SendEthResult = Result.Result<Text, Text>;
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

  // -----------------------------
  // Minimal HTTP outcall interface
  // -----------------------------

  type HttpResponsePayload = HttpTypes.HttpResponsePayload;
  type TransformArgs = HttpTypes.TransformArgs;
  type HttpRequestArgs = HttpTypes.HttpRequestArgs;

  transient let ic : Llm.Http = actor ("aaaaa-aa");
  transient let ic00 : Wallet.Ic00 = actor ("aaaaa-aa");
  transient let icpLedgerPrincipal : Principal = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");

  // -----------------------------
  // Inbound canister HTTP (for Telegram webhooks)
  // -----------------------------

  type HeaderField = (Text, Text);
  type InHttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };
  type InHttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
    streaming_strategy : ?{
      #Callback : {
        callback : shared query () -> async (); // unused
        token : Blob;
      }
    };
    upgrade : ?Bool;
  };

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

  func headerGet(headers : [HeaderField], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
      if (Text.toLowercase(k) == Text.toLowercase(key)) return ?v;
    };
    null
  };

  // Canister HTTP entrypoint (query): upgrade Telegram webhooks to update.
  public query func http_request(req : InHttpRequest) : async InHttpResponse {
    if (req.method == "POST" and Text.startsWith(req.url, #text "/tg/webhook")) {
      return {
        status_code = 200;
        headers = [("content-type", "text/plain")];
        body = Text.encodeUtf8("ok");
        streaming_strategy = null;
        upgrade = ?true;
      };
    };

    {
      status_code = 404;
      headers = [("content-type", "text/plain")];
      body = Text.encodeUtf8("not found");
      streaming_strategy = null;
      upgrade = null;
    }
  };

  // Canister HTTP update handler: process Telegram webhook.
  public shared ({ caller = _ }) func http_request_update(req : InHttpRequest) : async InHttpResponse {
    if (not (req.method == "POST" and Text.startsWith(req.url, #text "/tg/webhook"))) {
      return {
        status_code = 404;
        headers = [("content-type", "text/plain")];
        body = Text.encodeUtf8("not found");
        streaming_strategy = null;
        upgrade = null;
      };
    };

    // Optional secret check.
    switch (tgSecretToken) {
      case null {};
      case (?secret) {
        let hdr = headerGet(req.headers, "x-telegram-bot-api-secret-token");
        if (hdr != ?secret) {
          return {
            status_code = 401;
            headers = [("content-type", "text/plain")];
            body = Text.encodeUtf8("unauthorized");
            streaming_strategy = null;
            upgrade = null;
          };
        };
      };
    };

    let bodyText = switch (Text.decodeUtf8(req.body)) {
      case null {
        return {
          status_code = 400;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("bad request");
          streaming_strategy = null;
          upgrade = null;
        };
      };
      case (?t) t;
    };

    let parsed = Telegram.parseUpdate(bodyText);
    switch (parsed) {
      case null {
        return {
          status_code = 200;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("ok");
          streaming_strategy = null;
          upgrade = null;
        };
      };
      case (?u) {
        let token = switch (tgBotToken) {
          case null return {
            status_code = 503;
            headers = [("content-type", "text/plain")];
            body = Text.encodeUtf8("telegram not configured");
            streaming_strategy = null;
            upgrade = null;
          };
          case (?t) t;
        };

        let opts = switch (tgLlmOpts) {
          case null return {
            status_code = 503;
            headers = [("content-type", "text/plain")];
            body = Text.encodeUtf8("llm not configured");
            streaming_strategy = null;
            upgrade = null;
          };
          case (?o) o;
        };

        // Use canister principal as a dedicated namespace so it doesn't collide with anonymous web users.
        let tgUser = Principal.fromActor(OpenClawOnICP);
        let sessionId = "tg:" # Nat.toText(u.chatId);

        let sendRes = await Sessions.send(users, tgUser, sessionId, u.text, opts, nowNs, modelCaller);
        switch (sendRes) {
          case (#err(_)) {};
          case (#ok(ok)) {
            ignore await Telegram.sendMessage(ic, http_transform, defaultHttpCycles, token, u.chatId, ok.assistant.content);
          };
        };

        {
          status_code = 200;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("ok");
          streaming_strategy = null;
          upgrade = null;
        }
      };
    }
  };

  // -----------------------------
  // State + upgrades
  // -----------------------------

  var usersStore : [(Principal, Store.UserStore)] = [];
  transient var users = Store.initUsers();

  system func preupgrade() {
    usersStore := Store.toStore(users);
  };

  system func postupgrade() {
    users := Store.fromStore(usersStore);
  };

  func nowNs() : Int { Time.now() };

  public shared ({ caller }) func whoami() : async Text {
    assertOwner(caller);
    Principal.toText(caller)
  };

  public shared ({ caller }) func ecdsa_public_key(derivationPath : [Blob], keyName : ?Text) : async EcdsaPublicKeyResult {
    assertOwner(caller);
    await Wallet.ecdsaPublicKey(ic00, caller, Principal.fromActor(OpenClawOnICP), derivationPath, keyName)
  };

  public shared ({ caller }) func sign_with_ecdsa(messageHash : Blob, derivationPath : [Blob], keyName : ?Text) : async SignWithEcdsaResult {
    assertOwner(caller);
    await Wallet.signWithEcdsa(ic00, caller, messageHash, derivationPath, keyName)
  };

  public shared ({ caller }) func agent_wallet() : async WalletResult {
    assertOwner(caller);
    await Wallet.agentWallet(ic00, caller, Principal.fromActor(OpenClawOnICP))
  };

  public shared query ({ caller }) func canister_principal() : async Principal {
    assertOwnerQuery(caller);
    Principal.fromActor(OpenClawOnICP)
  };

  public shared ({ caller }) func wallet_send_icp(toPrincipalText : Text, amountE8s : Nat64) : async SendIcpResult {
    assertOwner(caller);
    await TokenTransfer.send(icpLedgerPrincipal, toPrincipalText, Nat64.toNat(amountE8s), null, null, null)
  };

  public shared ({ caller }) func wallet_send_icrc1(ledgerPrincipalText : Text, toPrincipalText : Text, amount : Nat, fee : ?Nat) : async SendIcrc1Result {
    assertOwner(caller);
    let ledgerPrincipal : Principal = try {
      Principal.fromText(Text.trim(ledgerPrincipalText, #char ' '))
    } catch (_) {
      return #err("invalid ledger principal")
    };
    await TokenTransfer.send(ledgerPrincipal, toPrincipalText, amount, fee, null, null)
  };

  public shared ({ caller }) func wallet_balance_icp() : async BalanceResult {
    assertOwner(caller);
    await TokenTransfer.balance(icpLedgerPrincipal, Principal.fromActor(OpenClawOnICP))
  };

  public shared ({ caller }) func wallet_balance_icrc1(ledgerPrincipalText : Text) : async BalanceResult {
    assertOwner(caller);
    let ledgerPrincipal : Principal = try {
      Principal.fromText(Text.trim(ledgerPrincipalText, #char ' '))
    } catch (_) {
      return #err("invalid ledger principal")
    };
    await TokenTransfer.balance(ledgerPrincipal, Principal.fromActor(OpenClawOnICP))
  };

  public shared ({ caller }) func wallet_send_eth_raw(network : Text, rpcUrl : ?Text, rawTxHex : Text) : async SendEthResult {
    assertOwner(caller);
    await EthTx.sendRaw(ic, http_transform, defaultHttpCycles, network, rpcUrl, rawTxHex)
  };

  public shared ({ caller }) func wallet_send_eth(network : Text, rpcUrl : ?Text, toAddress : Text, amountWei : Nat) : async SendEthResult {
    assertOwner(caller);
    await EthTx.send(
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
    await EthTx.sendErc20(
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

  public shared ({ caller }) func wallet_balance_eth(network : Text, rpcUrl : ?Text) : async BalanceResult {
    assertOwner(caller);
    await EthTx.balanceEth(
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
    await EthTx.balanceErc20(
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
    if (Text.size(Text.trim(apiKey, #char ' ')) == 0) return #err("apiKey is required");
    await Llm.listModels(ic, http_transform, defaultHttpCycles, provider, apiKey)
  };

  func modelCaller(
    provider : Provider,
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [ChatMessage],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) : async Result.Result<Text, Text> {
    await Llm.callModel(ic, http_transform, defaultHttpCycles, provider, model, apiKey, sysPrompt, history, maxTokens, temperature)
  };

  public shared ({ caller }) func sessions_send(sessionId : Text, message : Text, opts : SendOptions) : async SendResult {
    assertOwner(caller);
    await Sessions.send(users, caller, sessionId, message, opts, nowNs, modelCaller)
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
