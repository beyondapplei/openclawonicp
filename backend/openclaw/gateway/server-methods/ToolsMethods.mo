import Principal "mo:base/Principal";

import LlmToolRouter "../../llm/LlmToolRouter";
import Types "../../core/Types";
import Sessions "../../core/Sessions";

module {
  public type Deps = {
    assertAuthenticated : (caller : Principal) -> ();
    isOwner : (caller : Principal) -> Bool;
    apiToolCallerFor : (callerPrincipal : Principal, includeOwnerTools : Bool) -> Sessions.ToolCaller;
  };

  public func list(deps : Deps, caller : Principal) : [Text] {
    deps.assertAuthenticated(caller);
    LlmToolRouter.listToolNames(#api, deps.isOwner(caller), null)
  };

  public func invoke(deps : Deps, caller : Principal, name : Text, args : [Text]) : async Types.ToolResult {
    deps.assertAuthenticated(caller);
    let toolCaller = deps.apiToolCallerFor(caller, deps.isOwner(caller));
    await toolCaller(name, args)
  };
}
