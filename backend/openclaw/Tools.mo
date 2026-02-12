import Int "mo:base/Int";

import Store "./Store";
import Types "./Types";

module {
  public func list() : [Text] { ["kv.get", "kv.put", "time.nowNs"] };

  public func invoke(u : Store.UserState, name : Text, args : [Text], nowNs : () -> Int) : Types.ToolResult {
    switch (name) {
      case ("kv.get") {
        if (args.size() < 1) return #err("kv.get requires 1 arg: key");
        switch (u.kv.get(args[0])) {
          case null #ok("");
          case (?v) #ok(v);
        }
      };
      case ("kv.put") {
        if (args.size() < 2) return #err("kv.put requires 2 args: key, value");
        u.kv.put(args[0], args[1]);
        #ok("ok")
      };
      case ("time.nowNs") { #ok(Int.toText(nowNs())) };
      case (_) { #err("unknown tool") };
    }
  };
}
