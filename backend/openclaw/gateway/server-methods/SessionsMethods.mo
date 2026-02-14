import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Dispatch "../../auto_reply/Dispatch";
import Sessions "../../core/Sessions";
import Store "../../core/Store";
import Types "../../core/Types";

module {
  public type Deps = {
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    nowNs : () -> Int;
    assertAuthenticated : (caller : Principal) -> ();
    assertOwnerQuery : (caller : Principal) -> ();
    isOwner : (caller : Principal) -> Bool;
    resolveApiKeyForCaller : (caller : Principal, provider : Types.Provider, providedApiKey : Text) -> Result.Result<Text, Text>;
    modelCaller : (
      provider : Types.Provider,
      model : Text,
      apiKey : Text,
      sysPrompt : Text,
      history : [Types.ChatMessage],
      toolSpecs : [Sessions.ToolSpec],
      maxTokens : ?Nat,
      temperature : ?Float,
    ) -> async Result.Result<Text, Text>;
    llmToolSpecsFor : (sessionId : Text, includeOwnerTools : Bool) -> [Sessions.ToolSpec];
    llmToolCallerFor : (callerPrincipal : Principal, sessionId : Text, includeOwnerTools : Bool) -> Sessions.ToolCaller;
  };

  public func create(deps : Deps, caller : Principal, sessionId : Text) {
    deps.assertAuthenticated(caller);
    Sessions.create(deps.users, caller, sessionId, deps.nowNs);
  };

  public func reset(deps : Deps, caller : Principal, sessionId : Text) {
    deps.assertAuthenticated(caller);
    Sessions.reset(deps.users, caller, sessionId, deps.nowNs);
  };

  public func listFor(deps : Deps, caller : Principal, principal : Principal) : [Types.SessionSummary] {
    deps.assertOwnerQuery(caller);
    switch (deps.users.get(principal)) {
      case null [];
      case (?u) Sessions.list(u);
    }
  };

  public func list(deps : Deps, caller : Principal) : [Types.SessionSummary] {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Sessions.list(u)
  };

  public func history(deps : Deps, caller : Principal, sessionId : Text, limit : Nat) : [Types.ChatMessage] {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Sessions.history(u, sessionId, limit, deps.nowNs)
  };

  public func send(deps : Deps, caller : Principal, sessionId : Text, message : Text, opts : Types.SendOptions) : async Types.SendResult {
    deps.assertAuthenticated(caller);
    let resolvedApiKey = switch (deps.resolveApiKeyForCaller(caller, opts.provider, opts.apiKey)) {
      case (#err(e)) return #err(e);
      case (#ok(k)) k;
    };

    let opts2 : Types.SendOptions = {
      provider = opts.provider;
      model = opts.model;
      apiKey = resolvedApiKey;
      systemPrompt = opts.systemPrompt;
      maxTokens = opts.maxTokens;
      temperature = opts.temperature;
      skillNames = opts.skillNames;
      includeHistory = opts.includeHistory;
    };

    let includeOwnerTools = deps.isOwner(caller);
    let toolCaller = deps.llmToolCallerFor(caller, sessionId, includeOwnerTools);
    let toolSpecs = deps.llmToolSpecsFor(sessionId, includeOwnerTools);

    await Dispatch.dispatchInboundMessage({
      users = deps.users;
      caller = caller;
      sessionId = sessionId;
      message = message;
      opts = opts2;
      nowNs = deps.nowNs;
      modelCaller = deps.modelCaller;
      toolCaller = ?toolCaller;
      toolSpecs = toolSpecs;
    })
  };
}
