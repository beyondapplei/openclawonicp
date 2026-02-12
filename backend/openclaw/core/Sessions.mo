import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Hooks "./Hooks";
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
    let toolPrompt = buildToolPrompt(toolSpecs);
    let sysPrompt = baseSysPrompt # toolPrompt;
    let hist = if (opts.includeHistory) lastMessages(s, 20) else [{ role = #user; content = message; tsNs = ts }];

    let rawResult = await callModel(opts.provider, opts.model, opts.apiKey, sysPrompt, hist, opts.maxTokens, opts.temperature);
    switch (rawResult) {
      case (#err(e)) { #err(e) };
      case (#ok(raw)) {
        switch (Llm.extract(opts.provider, raw)) {
          case null { #err("model response parse failed") };
          case (?assistantText) {
            switch (parseToolCall(assistantText)) {
              case (?toolCall) {
                switch (callTool) {
                  case null {
                    let msg : Types.ChatMessage = { role = #assistant; content = stripToolPrefixLine(assistantText); tsNs = nowNs() };
                    s.messages.add(msg);
                    s.updatedAtNs := msg.tsNs;
                    return #ok({ assistant = msg; raw = ?raw });
                  };
                  case (?invokeTool) {
                    let toolRes = await invokeTool(toolCall.name, toolCall.args);
                    let toolMsgText = switch (toolRes) {
                      case (#ok(v)) toolCall.name # " ok: " # v;
                      case (#err(e)) toolCall.name # " err: " # e;
                    };
                    let toolMsg : Types.ChatMessage = { role = #tool; content = toolMsgText; tsNs = nowNs() };
                    s.messages.add(toolMsg);

                    let finalText = switch (toolRes) {
                      case (#ok(v)) "已执行工具 " # toolCall.name # "，结果：" # v;
                      case (#err(e)) "工具 " # toolCall.name # " 执行失败：" # e;
                    };
                    let msg : Types.ChatMessage = { role = #assistant; content = finalText; tsNs = nowNs() };
                    s.messages.add(msg);
                    s.updatedAtNs := msg.tsNs;
                    return #ok({ assistant = msg; raw = ?raw });
                  };
                }
              };
              case null {};
            };

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

  type ParsedToolCall = {
    name : Text;
    args : [Text];
  };

  func buildToolPrompt(specs : [ToolSpec]) : Text {
    if (specs.size() == 0) return "";
    let lines = Buffer.Buffer<Text>(specs.size() + 6);
    lines.add("\n\nTool use policy:");
    lines.add("- If a tool is needed, first line MUST be: [TOOL]<name>|<arg1>|<arg2>|...");
    lines.add("- Keep arguments plain text and use integer strings for numeric args.");
    lines.add("- Available tools:");
    for (spec in specs.vals()) {
      lines.add("  - [TOOL]" # spec.name # "|" # spec.argsHint # " ; " # spec.rule);
    };
    lines.add("- After the tool line, you may add a short confirmation sentence.");
    Text.join("\n", lines.vals())
  };

  func parseToolCall(text : Text) : ?ParsedToolCall {
    let marker = "[TOOL]";
    let parts = Text.split(text, #text marker);
    ignore parts.next();
    switch (parts.next()) {
      case null null;
      case (?afterMarker) {
        let line = firstLine(afterMarker);
        let segs = Text.split(line, #text "|");
        switch (segs.next()) {
          case null null;
          case (?nameRaw) {
            let name = Text.trim(nameRaw, #char ' ');
            if (Text.size(name) == 0) return null;
            let argsBuf = Buffer.Buffer<Text>(4);
            for (arg in segs) {
              let a = Text.trim(arg, #char ' ');
              if (Text.size(a) > 0) argsBuf.add(a);
            };
            ?{ name; args = Buffer.toArray(argsBuf) }
          };
        }
      };
    }
  };

  func firstLine(text : Text) : Text {
    let lines = Text.split(text, #char '\n');
    switch (lines.next()) {
      case null "";
      case (?l) l;
    }
  };

  func stripToolPrefixLine(text : Text) : Text {
    let marker = "[TOOL]";
    if (not Text.contains(text, #text marker)) return text;
    let lines = Buffer.Buffer<Text>(4);
    for (line in Text.split(text, #char '\n')) {
      if (Text.startsWith(Text.trim(line, #char ' '), #text marker)) {
      } else {
        lines.add(line);
      }
    };
    let out = Text.join("\n", lines.vals());
    Text.trim(out, #char ' ')
  };
}
