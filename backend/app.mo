import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import HttpTypes "./openclaw/HttpTypes";
import Llm "./openclaw/Llm";
import Sessions "./openclaw/Sessions";
import Skills "./openclaw/Skills";
import Store "./openclaw/Store";
import Tools "./openclaw/Tools";
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

  // -----------------------------
  // Minimal HTTP outcall interface
  // -----------------------------

  type HttpResponsePayload = HttpTypes.HttpResponsePayload;
  type TransformArgs = HttpTypes.TransformArgs;
  type HttpRequestArgs = HttpTypes.HttpRequestArgs;

  transient let ic : Llm.Http = actor ("aaaaa-aa");

  public query func http_transform(args : TransformArgs) : async HttpResponsePayload {
    { status = args.response.status; headers = []; body = args.response.body };
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
