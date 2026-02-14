import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Hooks "./Hooks";
import Json "../http/Json";
import Llm "../llm/Llm";
import Skills "./Skills";
import Store "./Store";
import ToolTypes "../llm/ToolTypes";
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
  public type ToolSpec = ToolTypes.ToolSpec;

  let maxToolSteps : Nat = 1;

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
        return localAssistant(
          s,
          nowNs,
          "Available commands:\n" #
          "/help\n" #
          "/status\n" #
          "/new\n" #
          "/reset",
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

    let sysPrompt = Skills.buildSystemPrompt(u, opts.systemPrompt, opts.skillNames);
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
      case (#err(e)) #err(e);
      case (#ok(raw)) {
        await continueModelWithTools(
          s,
          nowNs,
          raw,
          0,
          opts,
          callModel,
          callTool,
          toolSpecs,
          sysPrompt,
        )
      };
    }
  };

  func continueModelWithTools(
    s : Store.SessionState,
    nowNs : () -> Int,
    raw : Text,
    toolSteps : Nat,
    opts : Types.SendOptions,
    _callModel : ModelCaller,
    callTool : ?ToolCaller,
    toolSpecs : [ToolSpec],
    _sysPrompt : Text,
  ) : async Types.SendResult {
    switch (parseStructuredToolCall(opts.provider, raw, toolSpecs)) {
      case null {
        switch (Llm.extract(opts.provider, raw)) {
          case (?assistantText) {
            let msg : Types.ChatMessage = { role = #assistant; content = assistantText; tsNs = nowNs() };
            s.messages.add(msg);
            s.updatedAtNs := msg.tsNs;
            #ok({ assistant = msg; raw = ?raw })
          };
          case null {
            if (toolSteps == 0) {
              #err("model response parse failed")
            } else {
              localAssistant(s, nowNs, "工具执行完成，但模型未返回可解析文本。")
            }
          };
        }
      };
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
            #ok({ assistant = msg; raw = ?raw })
          };
          case (?invokeTool) {
            if (toolSteps >= maxToolSteps) {
              return localAssistant(
                s,
                nowNs,
                "工具调用达到上限（" # Nat.toText(maxToolSteps) # "），已停止继续调用。",
              );
            };

            let toolRes = await invokeTool(toolCall.name, toolCall.args);
            let toolMsgText = switch (toolRes) {
              case (#ok(v)) toolCall.name # " ok: " # v;
              case (#err(e)) toolCall.name # " err: " # e;
            };
            let toolMsg : Types.ChatMessage = { role = #tool; content = toolMsgText; tsNs = nowNs() };
            s.messages.add(toolMsg);
            // Single-pass mode: execute tool once and return directly,
            // without calling the model a second time.
            fallbackToolSummary(s, nowNs, toolCall, toolRes, ?raw)
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

  func parseStructuredToolCall(provider : Types.Provider, raw : Text, toolSpecs : [ToolSpec]) : ?ParsedToolCall {
    switch (provider) {
      case (#openai) parseOpenAIToolCall(raw, toolSpecs);
      case (#anthropic) parseAnthropicToolCall(raw, toolSpecs);
      case (#google) parseGoogleToolCall(raw, toolSpecs);
    }
  };

  func parseOpenAIToolCall(raw : Text, toolSpecs : [ToolSpec]) : ?ParsedToolCall {
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

    let argsObj = switch (Json.extractStringAfterAny(after, ["\"arguments\":\"", "\"arguments\": \""])) {
      case null "{}";
      case (?v) v;
    };
    ?{
      name;
      args = argsFromJsonObject(name, argsObj, toolSpecs);
    }
  };

  func parseAnthropicToolCall(raw : Text, toolSpecs : [ToolSpec]) : ?ParsedToolCall {
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

    let argsObj = switch (Json.extractObjectAfterAny(after, ["\"input\":", "\"input\": "])) {
      case null "{}";
      case (?v) v;
    };
    ?{
      name;
      args = argsFromJsonObject(name, argsObj, toolSpecs);
    }
  };

  func parseGoogleToolCall(raw : Text, toolSpecs : [ToolSpec]) : ?ParsedToolCall {
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

    let argsObj = switch (Json.extractObjectAfterAny(after, ["\"args\":", "\"args\": "])) {
      case null "{}";
      case (?v) v;
    };
    ?{
      name;
      args = argsFromJsonObject(name, argsObj, toolSpecs);
    }
  };

  func argsFromJsonObject(name : Text, obj : Text, specs : [ToolSpec]) : [Text] {
    let spec = switch (findToolSpec(specs, name)) {
      case null return [];
      case (?v) v;
    };
    let out = Buffer.Buffer<Text>(spec.argNames.size());
    for (argName in spec.argNames.vals()) {
      switch (extractArgAsText(obj, argName)) {
        case null out.add("");
        case (?v) out.add(Text.trim(v, #char ' '));
      }
    };
    Buffer.toArray(out)
  };

  func findToolSpec(specs : [ToolSpec], name : Text) : ?ToolSpec {
    for (s in specs.vals()) {
      if (s.name == name) return ?s;
    };
    null
  };

  func extractArgAsText(obj : Text, key : Text) : ?Text {
    let quoted = "\"" # key # "\":\"";
    let quotedSpaced = "\"" # key # "\": \"";
    switch (Json.extractStringAfterAny(obj, [quoted, quotedSpaced])) {
      case (?v) return ?v;
      case null {};
    };

    let boolTrue = "\"" # key # "\":true";
    let boolTrueSpaced = "\"" # key # "\": true";
    if (Text.contains(obj, #text boolTrue) or Text.contains(obj, #text boolTrueSpaced)) {
      return ?"true";
    };
    let boolFalse = "\"" # key # "\":false";
    let boolFalseSpaced = "\"" # key # "\": false";
    if (Text.contains(obj, #text boolFalse) or Text.contains(obj, #text boolFalseSpaced)) {
      return ?"false";
    };

    let natNeedle = "\"" # key # "\":";
    let natNeedleSpaced = "\"" # key # "\": ";
    switch (extractNatAfterAny(obj, [natNeedle, natNeedleSpaced])) {
      case null null;
      case (?n) ?Nat.toText(n);
    }
  };

  func extractNatAfterAny(raw : Text, needles : [Text]) : ?Nat {
    for (n in needles.vals()) {
      switch (extractNatAfter(raw, n)) {
        case null {};
        case (?v) return ?v;
      }
    };
    null
  };

  func extractNatAfter(raw : Text, needle : Text) : ?Nat {
    let it = Text.split(raw, #text needle);
    ignore it.next();
    switch (it.next()) {
      case null null;
      case (?after) readNatPrefix(after);
    }
  };

  func readNatPrefix(t : Text) : ?Nat {
    var acc : Nat = 0;
    var seen = false;
    for (c in t.chars()) {
      if (c == ' ' or c == '\n' or c == '\r' or c == '\t') {
        if (seen) return ?acc;
      } else if (c >= '0' and c <= '9') {
        seen := true;
        acc := acc * 10 + Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
      } else {
        if (seen) return ?acc else return null;
      }
    };
    if (seen) ?acc else null
  };
}
