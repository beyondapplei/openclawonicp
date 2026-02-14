import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";

import Skills "../../core/Skills";
import Store "../../core/Store";

module {
  public type Deps = {
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    nowNs : () -> Int;
    assertAuthenticated : (caller : Principal) -> ();
  };

  public func put(deps : Deps, caller : Principal, name : Text, markdown : Text) {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Skills.put(u, name, markdown, deps.nowNs);
  };

  public func get(deps : Deps, caller : Principal, name : Text) : ?Text {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Skills.get(u, name)
  };

  public func list(deps : Deps, caller : Principal) : [Text] {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Skills.list(u)
  };

  public func delete(deps : Deps, caller : Principal, name : Text) : Bool {
    deps.assertAuthenticated(caller);
    let u = Store.getOrInitUser(deps.users, caller);
    Skills.delete(u, name)
  };
}
