import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

import Store "./Store";
import Types "./Types";

module {
  public type HookTrigger = {
    #command : Text;
    #messageContains : Text;
  };

  public type HookAction = {
    #reply : Text;
    #tool : {
      name : Text;
      args : [Text];
    };
  };

  public type HookEntry = {
    name : Text;
    trigger : HookTrigger;
    action : HookAction;
    enabled : Bool;
  };

  public type ToolCaller = (name : Text, args : [Text]) -> async Types.ToolResult;

  public func putCommandReply(u : Store.UserState, name : Text, command : Text, reply : Text) : Bool {
    let n = normalize(name);
    let c = normalize(command);
    if (Text.size(n) == 0 or Text.size(c) == 0) return false;
    putRaw(u, n, "command", c, "reply", Text.trim(reply, #char ' '), getEnabledOrDefault(u, n));
    true
  };

  public func putMessageReply(u : Store.UserState, name : Text, keyword : Text, reply : Text) : Bool {
    let n = normalize(name);
    let k = normalize(keyword);
    if (Text.size(n) == 0 or Text.size(k) == 0) return false;
    putRaw(u, n, "messageContains", k, "reply", Text.trim(reply, #char ' '), getEnabledOrDefault(u, n));
    true
  };

  public func putCommandTool(u : Store.UserState, name : Text, command : Text, toolName : Text, toolArgs : [Text]) : Bool {
    let n = normalize(name);
    let c = normalize(command);
    let t = normalize(toolName);
    if (Text.size(n) == 0 or Text.size(c) == 0 or Text.size(t) == 0) return false;
    putRaw(u, n, "command", c, "tool", encodeToolValue(t, toolArgs), getEnabledOrDefault(u, n));
    true
  };

  public func putMessageTool(u : Store.UserState, name : Text, keyword : Text, toolName : Text, toolArgs : [Text]) : Bool {
    let n = normalize(name);
    let k = normalize(keyword);
    let t = normalize(toolName);
    if (Text.size(n) == 0 or Text.size(k) == 0 or Text.size(t) == 0) return false;
    putRaw(u, n, "messageContains", k, "tool", encodeToolValue(t, toolArgs), getEnabledOrDefault(u, n));
    true
  };

  public func setEnabled(u : Store.UserState, name : Text, enabled : Bool) : Bool {
    let n = normalize(name);
    if (Text.size(n) == 0) return false;
    switch (getByName(u, n)) {
      case null false;
      case (?_) {
        u.kv.put(hookKey(n, "enabled"), if (enabled) "1" else "0");
        true
      }
    }
  };

  public func summaryText(u : Store.UserState) : Text {
    let all = list(u);
    var enabled : Nat = 0;
    for (h in all.vals()) {
      if (h.enabled) enabled += 1;
    };
    "hooks: " # Nat.toText(enabled) # " enabled / " # Nat.toText(all.size()) # " total"
  };

  public func delete(u : Store.UserState, name : Text) : Bool {
    let n = normalize(name);
    if (Text.size(n) == 0) return false;
    var removed = false;
    for (field in hookFields().vals()) {
      switch (u.kv.remove(hookKey(n, field))) {
        case null {};
        case (?_) { removed := true };
      }
    };
    removed
  };

  public func list(u : Store.UserState) : [HookEntry] {
    let names = hookNames(u);
    let out = Buffer.Buffer<HookEntry>(names.size());
    for (name in names.vals()) {
      switch (getByName(u, name)) {
        case null {};
        case (?h) out.add(h);
      }
    };
    Buffer.toArray(out)
  };

  public func handleCommand(u : Store.UserState, commandText : Text, invokeTool : ?ToolCaller) : async ?Text {
    let cmd = normalize(commandText);
    if (Text.size(cmd) == 0) return null;
    switch (firstMatch(u, func(h : HookEntry) : Bool {
      if (not h.enabled) return false;
      switch (h.trigger) {
        case (#command(v)) v == cmd;
        case (_) false;
      }
    })) {
      case null null;
      case (?h) await runAction(h, invokeTool);
    }
  };

  public func handleMessage(u : Store.UserState, messageText : Text, invokeTool : ?ToolCaller) : async ?Text {
    let msg = normalize(messageText);
    if (Text.size(msg) == 0) return null;
    switch (firstMatch(u, func(h : HookEntry) : Bool {
      if (not h.enabled) return false;
      switch (h.trigger) {
        case (#messageContains(v)) Text.contains(msg, #text v);
        case (_) false;
      }
    })) {
      case null null;
      case (?h) await runAction(h, invokeTool);
    }
  };

  func runAction(h : HookEntry, invokeTool : ?ToolCaller) : async ?Text {
    switch (h.action) {
      case (#reply(text)) ?text;
      case (#tool(spec)) {
        switch (invokeTool) {
          case null ?("hook " # h.name # " failed: tool caller not available");
          case (?f) {
            switch (await f(spec.name, spec.args)) {
              case (#ok(v)) {
                if (Text.size(Text.trim(v, #char ' ')) == 0) {
                  ?("hook " # h.name # " executed")
                } else {
                  ?("hook " # h.name # " result: " # v)
                }
              };
              case (#err(e)) ?("hook " # h.name # " error: " # e);
            }
          };
        }
      };
    }
  };

  func firstMatch(u : Store.UserState, pred : (HookEntry) -> Bool) : ?HookEntry {
    let entries = list(u);
    var chosen : ?HookEntry = null;
    for (h in entries.vals()) {
      if (pred(h)) {
        switch (chosen) {
          case null { chosen := ?h };
          case (?c) {
            if (Text.compare(h.name, c.name) == #less) {
              chosen := ?h;
            }
          };
        }
      }
    };
    chosen
  };

  func putRaw(u : Store.UserState, name : Text, triggerType : Text, triggerValue : Text, actionType : Text, actionValue : Text, enabled : Bool) {
    u.kv.put(hookKey(name, "triggerType"), triggerType);
    u.kv.put(hookKey(name, "triggerValue"), triggerValue);
    u.kv.put(hookKey(name, "actionType"), actionType);
    u.kv.put(hookKey(name, "actionValue"), actionValue);
    u.kv.put(hookKey(name, "enabled"), if (enabled) "1" else "0");
  };

  func getEnabledOrDefault(u : Store.UserState, name : Text) : Bool {
    switch (u.kv.get(hookKey(name, "enabled"))) {
      case (?"0") false;
      case (_) true;
    }
  };

  func getByName(u : Store.UserState, name : Text) : ?HookEntry {
    let triggerType = switch (u.kv.get(hookKey(name, "triggerType"))) {
      case null return null;
      case (?v) v;
    };
    let triggerValue = switch (u.kv.get(hookKey(name, "triggerValue"))) {
      case null return null;
      case (?v) v;
    };
    let actionType = switch (u.kv.get(hookKey(name, "actionType"))) {
      case null return null;
      case (?v) v;
    };
    let actionValue = switch (u.kv.get(hookKey(name, "actionValue"))) {
      case null return null;
      case (?v) v;
    };
    let enabled = switch (u.kv.get(hookKey(name, "enabled"))) {
      case (?"0") false;
      case (_) true;
    };

    let trigger : HookTrigger =
      if (triggerType == "command") {
        #command(triggerValue)
      } else if (triggerType == "messageContains") {
        #messageContains(triggerValue)
      } else {
        return null;
      };

    let action : HookAction =
      if (actionType == "reply") {
        #reply(actionValue)
      } else if (actionType == "tool") {
        switch (decodeToolValue(actionValue)) {
          case null return null;
          case (?spec) #tool(spec);
        }
      } else {
        return null;
      };

    ?{
      name = name;
      trigger = trigger;
      action = action;
      enabled = enabled;
    }
  };

  func hookNames(u : Store.UserState) : [Text] {
    let prefix = "hook:";
    let marker = ":triggerType";
    let out = Buffer.Buffer<Text>(8);
    for ((k, _) in u.kv.entries()) {
      if (Text.startsWith(k, #text prefix) and Text.endsWith(k, #text marker)) {
        let raw = Text.trimStart(k, #text prefix);
        let name = Text.trimEnd(raw, #text marker);
        if (Text.size(name) > 0) out.add(name);
      }
    };
    Buffer.toArray(out)
  };

  func hookFields() : [Text] {
    ["triggerType", "triggerValue", "actionType", "actionValue", "enabled"]
  };

  func hookKey(name : Text, field : Text) : Text {
    "hook:" # name # ":" # field
  };

  func encodeToolValue(toolName : Text, args : [Text]) : Text {
    let b = Buffer.Buffer<Text>(1 + args.size());
    b.add(toolName);
    for (a in args.vals()) { b.add(a) };
    Text.join("\u{001F}", b.vals())
  };

  func decodeToolValue(raw : Text) : ?{ name : Text; args : [Text] } {
    let parts = Text.split(raw, #text "\u{001F}");
    let first = switch (parts.next()) {
      case null return null;
      case (?v) normalize(v);
    };
    if (Text.size(first) == 0) return null;
    let args = Buffer.Buffer<Text>(4);
    for (p in parts) {
      args.add(Text.trim(p, #char ' '));
    };
    ?{
      name = first;
      args = Buffer.toArray(args);
    }
  };

  func normalize(t : Text) : Text {
    Text.toLowercase(Text.trim(t, #char ' '))
  };
}
