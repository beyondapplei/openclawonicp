import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Hooks "./Hooks";
import Json "../http/Json";
import Llm "../llm/Llm";
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
    toolSpecs : [ToolSpec],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) -> async Result.Result<Text, Text>;

  public type ToolCaller = (name : Text, args : [Text]) -> async Types.ToolResult;
  public type ToolSpec = {
    name : Text;
    argsHint : Text;
    rule : Text;
  };

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
    callTool : ?ToolCaller,
    toolSpecs : [ToolSpec],
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
      switch (await Hooks.handleCommand(u, trimmed, callTool)) {
        case (?replyText) {
          return localAssistant(s, nowNs, replyText);
        };
        case null {};
      };

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
          "includeHistory: " # (if (opts.includeHistory) "true" else "false") # "\n" #
          Hooks.summaryText(u);
        return localAssistant(s, nowNs, text);
      };

      if (cmd == "/hooks") {
        return localAssistant(s, nowNs, Hooks.summaryText(u));
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

    switch (await Hooks.handleMessage(u, trimmed, callTool)) {
      case (?replyText) {
        return localAssistant(s, nowNs, replyText);
      };
      case null {};
    };

    let baseSysPrompt = Skills.buildSystemPrompt(u, opts.systemPrompt, opts.skillNames);
    let toolPrompt = "";
    let sysPrompt = baseSysPrompt # toolPrompt;
    let hist = if (opts.includeHistory) lastMessages(s, 20) else [{ role = #user; content = message; tsNs = ts }];

    let rawResult = await callModel(
      opts.provider,
      opts.model,
      opts.apiKey,
      sysPrompt,
      hist,
      toolSpecs,
      opts.maxTokens,
      opts.temperature,
    );
    switch (rawResult) {
      case (#err(e)) { #err(e) };
      case (#ok(raw)) {
        switch (parseStructuredToolCall(opts.provider, raw)) {
          case (?toolCall) {
            switch (callTool) {
              case null {
                let msg : Types.ChatMessage = {
                  role = #assistant;
                  content = "模型请求调用工具 " # toolCall.name # "，但当前未启用工具调用。";
                  tsNs = nowNs();
                };
                s.messages.add(msg);
                s.updatedAtNs := msg.tsNs;
                return #ok({ assistant = msg; raw = ?raw });
              };
              case (?invokeTool) {
                return await runToolAndFinalize(
                  s,
                  nowNs,
                  invokeTool,
                  toolCall,
                  opts,
                  callModel,
                  toolSpecs,
                  sysPrompt,
                  ?raw,
                );
              };
            }
          };
          case null {};
        };

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

  func runToolAndFinalize(
    s : Store.SessionState,
    nowNs : () -> Int,
    invokeTool : ToolCaller,
    toolCall : ParsedToolCall,
    opts : Types.SendOptions,
    callModel : ModelCaller,
    toolSpecs : [ToolSpec],
    sysPrompt : Text,
    firstRaw : ?Text,
  ) : async Types.SendResult {
    let toolRes = await invokeTool(toolCall.name, toolCall.args);
    let toolMsgText = switch (toolRes) {
      case (#ok(v)) toolCall.name # " ok: " # v;
      case (#err(e)) toolCall.name # " err: " # e;
    };
    let toolMsg : Types.ChatMessage = { role = #tool; content = toolMsgText; tsNs = nowNs() };
    s.messages.add(toolMsg);

    let hist2 = lastMessages(s, 20);
    let raw2Result = await callModel(
      opts.provider,
      opts.model,
      opts.apiKey,
      sysPrompt,
      hist2,
      toolSpecs,
      opts.maxTokens,
      opts.temperature,
    );

    switch (raw2Result) {
      case (#ok(raw2)) {
        if (parseStructuredToolCall(opts.provider, raw2) != null) {
          return fallbackToolSummary(s, nowNs, toolCall, toolRes, firstRaw);
        };
        switch (Llm.extract(opts.provider, raw2)) {
          case (?assistantText) {
            let msg : Types.ChatMessage = { role = #assistant; content = assistantText; tsNs = nowNs() };
            s.messages.add(msg);
            s.updatedAtNs := msg.tsNs;
            #ok({ assistant = msg; raw = ?raw2 })
          };
          case null fallbackToolSummary(s, nowNs, toolCall, toolRes, firstRaw);
        }
      };
      case (#err(_)) fallbackToolSummary(s, nowNs, toolCall, toolRes, firstRaw);
    }
  };

  func fallbackToolSummary(
    s : Store.SessionState,
    nowNs : () -> Int,
    toolCall : ParsedToolCall,
    toolRes : Types.ToolResult,
    raw : ?Text,
  ) : Types.SendResult {
    let finalText = switch (toolRes) {
      case (#ok(v)) "已执行工具 " # toolCall.name # "，结果：" # v;
      case (#err(e)) "工具 " # toolCall.name # " 执行失败：" # e;
    };
    let msg : Types.ChatMessage = { role = #assistant; content = finalText; tsNs = nowNs() };
    s.messages.add(msg);
    s.updatedAtNs := msg.tsNs;
    #ok({ assistant = msg; raw = raw })
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

  type ParsedToolCall = {
    name : Text;
    args : [Text];
  };

  func parseStructuredToolCall(provider : Types.Provider, raw : Text) : ?ParsedToolCall {
    switch (provider) {
      case (#openai) parseOpenAIToolCall(raw);
      case (#anthropic) parseAnthropicToolCall(raw);
      case (#google) parseGoogleToolCall(raw);
    }
  };

  func parseOpenAIToolCall(raw : Text) : ?ParsedToolCall {
    let segments = Text.split(raw, #text "\"tool_calls\"");
    ignore segments.next();
    let after = switch (segments.next()) {
      case null return null;
      case (?v) v;
    };

    let name = switch (Json.extractStringAfterAny(after, ["\"name\":\"", "\"name\": \""])) {
      case null return null;
      case (?n) Text.trim(n, #char ' ');
    };
    if (Text.size(name) == 0) return null;

    let argsJson = switch (Json.extractStringAfterAny(after, ["\"arguments\":\"", "\"arguments\": \""])) {
      case null return ?{ name; args = [] };
      case (?v) v;
    };

    let argsLine = switch (Json.extractStringAfterAny(argsJson, ["\"args_line\":\"", "\"args_line\": \""])) {
      case null "";
      case (?v) v;
    };

    ?{ name; args = splitArgsLine(argsLine) }
  };

  func parseAnthropicToolCall(raw : Text) : ?ParsedToolCall {
    let segments = Text.split(raw, #text "\"type\":\"tool_use\"");
    ignore segments.next();
    let after = switch (segments.next()) {
      case null return null;
      case (?v) v;
    };

    let name = switch (Json.extractStringAfterAny(after, ["\"name\":\"", "\"name\": \""])) {
      case null return null;
      case (?n) Text.trim(n, #char ' ');
    };
    if (Text.size(name) == 0) return null;

    let argsLine = switch (Json.extractStringAfterAny(after, ["\"args_line\":\"", "\"args_line\": \""])) {
      case null "";
      case (?v) v;
    };

    ?{ name; args = splitArgsLine(argsLine) }
  };

  func parseGoogleToolCall(raw : Text) : ?ParsedToolCall {
    let segments = Text.split(raw, #text "\"functionCall\"");
    ignore segments.next();
    let after = switch (segments.next()) {
      case null return null;
      case (?v) v;
    };

    let name = switch (Json.extractStringAfterAny(after, ["\"name\":\"", "\"name\": \""])) {
      case null return null;
      case (?n) Text.trim(n, #char ' ');
    };
    if (Text.size(name) == 0) return null;

    let argsLine = switch (Json.extractStringAfterAny(after, ["\"args_line\":\"", "\"args_line\": \""])) {
      case null "";
      case (?v) v;
    };

    ?{ name; args = splitArgsLine(argsLine) }
  };

  func splitArgsLine(line : Text) : [Text] {
    let buf = Buffer.Buffer<Text>(4);
    for (part in Text.split(line, #text "|")) {
      let trimmed = Text.trim(part, #char ' ');
      if (Text.size(trimmed) > 0) buf.add(trimmed);
    };
    Buffer.toArray(buf)
  };
}
