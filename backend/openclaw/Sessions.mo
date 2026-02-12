import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Llm "./Llm";
import Skills "./Skills";
import Store "./Store";
import Types "./Types";

module {
  public type ModelCaller = (
    provider : Types.Provider,
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [Types.ChatMessage],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) -> async Result.Result<Text, Text>;

  public func create(users : TrieMap.TrieMap<Principal, Store.UserState>, caller : Principal, sessionId : Text, nowNs : () -> Int) {
    let u = Store.getOrInitUser(users, caller);
    ignore Store.getOrInitSession(u, sessionId, nowNs);
  };

  public func reset(users : TrieMap.TrieMap<Principal, Store.UserState>, caller : Principal, sessionId : Text, nowNs : () -> Int) {
    let u = Store.getOrInitUser(users, caller);
    let s = Store.getOrInitSession(u, sessionId, nowNs);
    s.messages.clear();
    s.updatedAtNs := nowNs();
  };

  public func list(u : Store.UserState) : [Types.SessionSummary] {
    let buf = Buffer.Buffer<Types.SessionSummary>(u.sessions.size());
    for ((id, s) in u.sessions.entries()) {
      buf.add({ id; updatedAtNs = s.updatedAtNs; messageCount = s.messages.size() });
    };
    Buffer.toArray(buf)
  };

  public func history(u : Store.UserState, sessionId : Text, limit : Nat, nowNs : () -> Int) : [Types.ChatMessage] {
    let s = Store.getOrInitSession(u, sessionId, nowNs);
    let n = s.messages.size();
    let take = if (limit >= n) n else limit;
    let start : Nat = n - take;
    let out = Buffer.Buffer<Types.ChatMessage>(take);
    var i : Nat = start;
    while (i < n) {
      out.add(s.messages.get(i));
      i += 1;
    };
    Buffer.toArray(out)
  };

  public func send(
    users : TrieMap.TrieMap<Principal, Store.UserState>,
    caller : Principal,
    sessionId : Text,
    message : Text,
    opts : Types.SendOptions,
    nowNs : () -> Int,
    callModel : ModelCaller,
  ) : async Types.SendResult {
    let trimmed = Text.trim(message, #char ' ');
    if (Text.size(trimmed) == 0) {
      return #err("message is empty");
    };
    if (Text.size(opts.model) == 0) {
      return #err("model is required");
    };
    if (Text.size(opts.apiKey) == 0) {
      return #err("apiKey is required (passed per-call per your choice)");
    };

    let u = Store.getOrInitUser(users, caller);
    let s = Store.getOrInitSession(u, sessionId, nowNs);

    // OpenClaw-like slash commands handled locally.
    if (Text.startsWith(trimmed, #text "/")) {
      let cmd = Text.toLowercase(trimmed);
      if (cmd == "/help") {
        return localAssistant(s, nowNs,
          "Available commands:\n" #
          "/help\n" #
          "/status\n" #
          "/new\n" #
          "/reset"
        );
      };

      if (cmd == "/status") {
        let text =
          "session: " # sessionId # "\n" #
          "provider: " # providerName(opts.provider) # "\n" #
          "model: " # opts.model # "\n" #
          "messages: " # Nat.toText(s.messages.size()) # "\n" #
          "skills: " # Nat.toText(u.skills.size()) # "\n" #
          "includeHistory: " # (if (opts.includeHistory) "true" else "false");
        return localAssistant(s, nowNs, text);
      };

      if (cmd == "/new" or cmd == "/reset") {
        s.messages.clear();
        s.updatedAtNs := nowNs();
        return localAssistant(s, nowNs, "Session reset.");
      };

      return localAssistant(s, nowNs, "Unknown command. Try /help");
    };

    let ts = nowNs();
    s.messages.add({ role = #user; content = message; tsNs = ts });
    s.updatedAtNs := ts;

    let sysPrompt = Skills.buildSystemPrompt(u, opts.systemPrompt, opts.skillNames);
    let hist = if (opts.includeHistory) lastMessages(s, 20) else [{ role = #user; content = message; tsNs = ts }];

    let rawResult = await callModel(opts.provider, opts.model, opts.apiKey, sysPrompt, hist, opts.maxTokens, opts.temperature);
    switch (rawResult) {
      case (#err(e)) { #err(e) };
      case (#ok(raw)) {
        switch (Llm.extract(opts.provider, raw)) {
          case null { #err("model response parse failed") };
          case (?assistantText) {
            let msg : Types.ChatMessage = { role = #assistant; content = assistantText; tsNs = nowNs() };
            s.messages.add(msg);
            s.updatedAtNs := msg.tsNs;
            #ok({ assistant = msg; raw = ?raw })
          };
        }
      };
    }
  };

  func localAssistant(s : Store.SessionState, nowNs : () -> Int, text : Text) : Types.SendResult {
    let msg : Types.ChatMessage = { role = #assistant; content = text; tsNs = nowNs() };
    s.messages.add(msg);
    s.updatedAtNs := msg.tsNs;
    #ok({ assistant = msg; raw = null })
  };

  func providerName(p : Types.Provider) : Text {
    switch (p) {
      case (#openai) "openai";
      case (#anthropic) "anthropic";
      case (#google) "google";
    }
  };

  func lastMessages(s : Store.SessionState, limit : Nat) : [Types.ChatMessage] {
    let n = s.messages.size();
    let take = if (limit >= n) n else limit;
    let start : Nat = n - take;
    let out = Buffer.Buffer<Types.ChatMessage>(take);
    var i : Nat = start;
    while (i < n) {
      out.add(s.messages.get(i));
      i += 1;
    };
    Buffer.toArray(out)
  };
}
