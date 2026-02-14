import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";

import Hooks "../../core/Hooks";
import Store "../../core/Store";

module {
  public type HookEntry = Hooks.HookEntry;

  public type Deps = {
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    assertAuthenticated : (caller : Principal) -> ();
  };

  public func list(deps : Deps, caller : Principal) : [HookEntry] {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Hooks.list(u)
  };

  public func putCommandReply(deps : Deps, caller : Principal, name : Text, command : Text, reply : Text) : Bool {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Hooks.putCommandReply(u, name, command, reply)
  };

  public func putMessageReply(deps : Deps, caller : Principal, name : Text, keyword : Text, reply : Text) : Bool {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Hooks.putMessageReply(u, name, keyword, reply)
  };

  public func putCommandTool(
    deps : Deps,
    caller : Principal,
    name : Text,
    command : Text,
    toolName : Text,
    toolArgs : [Text],
  ) : Bool {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Hooks.putCommandTool(u, name, command, toolName, toolArgs)
  };

  public func putMessageTool(
    deps : Deps,
    caller : Principal,
    name : Text,
    keyword : Text,
    toolName : Text,
    toolArgs : [Text],
  ) : Bool {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Hooks.putMessageTool(u, name, keyword, toolName, toolArgs)
  };

  public func delete(deps : Deps, caller : Principal, name : Text) : Bool {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Hooks.delete(u, name)
  };

  public func setEnabled(deps : Deps, caller : Principal, name : Text, enabled : Bool) : Bool {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Hooks.setEnabled(u, name, enabled)
  };
}
