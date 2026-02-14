import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";

import Sessions "../core/Sessions";
import Store "../core/Store";
import Types "../core/Types";

module {
  public type DispatchContext = {
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    caller : Principal;
    sessionId : Text;
    message : Text;
    opts : Types.SendOptions;
    nowNs : () -> Int;
    modelCaller : Sessions.ModelCaller;
    toolCaller : ?Sessions.ToolCaller;
    toolSpecs : [Sessions.ToolSpec];
  };

  public func dispatchInboundMessage(ctx : DispatchContext) : async Types.SendResult {
    await Sessions.send(
      ctx.users,
      ctx.caller,
      ctx.sessionId,
      ctx.message,
      ctx.opts,
      ctx.nowNs,
      ctx.modelCaller,
      ctx.toolCaller,
      ctx.toolSpecs,
    )
  };
}
