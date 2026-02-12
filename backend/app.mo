import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
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
    switch (owner) {
      case null { owner := ?caller };
      case (?o) { if (o != caller) { Debug.trap("not authorized") } };
    }
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

  public shared ({ caller = _ }) func tg_status() : async TgStatus {
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

  // -----------------------------
  // sessions_* (openclaw-like)
  // -----------------------------

  public shared ({ caller }) func sessions_create(sessionId : Text) : async () {
    Sessions.create(users, caller, sessionId, nowNs);
  };

  public shared ({ caller }) func sessions_reset(sessionId : Text) : async () {
    Sessions.reset(users, caller, sessionId, nowNs);
  };

  public query func sessions_list_for(principal : Principal) : async [SessionSummary] {
    switch (users.get(principal)) {
      case null [];
      case (?u) Sessions.list(u);
    }
  };

  public shared ({ caller }) func sessions_list() : async [SessionSummary] {
    let u = Store.getOrInitUser(users, caller);
    Sessions.list(u)
  };

  public shared ({ caller }) func sessions_history(sessionId : Text, limit : Nat) : async [ChatMessage] {
    let u = Store.getOrInitUser(users, caller);
    Sessions.history(u, sessionId, limit, nowNs)
  };

  transient let defaultHttpCycles : Nat = 30_000_000_000;

  // Model discovery (for UI dropdowns)
  public shared ({ caller = _ }) func models_list(provider : Provider, apiKey : Text) : async ModelsResult {
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
    await Sessions.send(users, caller, sessionId, message, opts, nowNs, modelCaller)
  };

  // -----------------------------
  // skills_* (ClawHub-like, minimal)
  // -----------------------------

  public shared ({ caller }) func skills_put(name : Text, markdown : Text) : async () {
    let u = Store.getOrInitUser(users, caller);
    Skills.put(u, name, markdown, nowNs);
  };

  public shared ({ caller }) func skills_get(name : Text) : async ?Text {
    let u = Store.getOrInitUser(users, caller);
    Skills.get(u, name)
  };

  public shared ({ caller }) func skills_list() : async [Text] {
    let u = Store.getOrInitUser(users, caller);
    Skills.list(u)
  };

  public shared ({ caller }) func skills_delete(name : Text) : async Bool {
    let u = Store.getOrInitUser(users, caller);
    Skills.delete(u, name)
  };

  // -----------------------------
  // tools_* (very limited, chain-safe)
  // -----------------------------

  public shared ({ caller = _ }) func tools_list() : async [Text] {
    Tools.list()
  };

  public shared ({ caller }) func tools_invoke(name : Text, args : [Text]) : async ToolResult {
    let u = Store.getOrInitUser(users, caller);
    Tools.invoke(u, name, args, nowNs)
  };
};
