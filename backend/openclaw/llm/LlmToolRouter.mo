import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import ToolRegistry "./ToolRegistry";

module {
  public type ToolResult = ToolTypes.ToolResult;
  public type SendIcpFn = ToolTypes.SendIcpFn;
  public type SendEthFn = ToolTypes.SendEthFn;
  public type SendTgFn = ToolTypes.SendTgFn;
  public type BuyCkEthFn = ToolTypes.BuyCkEthFn;
  public type ToolSpec = ToolTypes.ToolSpec;
  type DispatchDeps = ToolTypes.DispatchDeps;
  public let defaultSpecs : [ToolSpec] = ToolRegistry.specs;

  public func dispatch(
    name : Text,
    args : [Text],
    sendIcp : SendIcpFn,
    sendEth : SendEthFn,
    sendTg : SendTgFn,
    buyCkEth : BuyCkEthFn,
  ) : async ToolResult {
    let deps : DispatchDeps = {
      sendIcp = sendIcp;
      sendEth = sendEth;
      sendTg = sendTg;
      buyCkEth = buyCkEth;
    };
    switch (ToolRegistry.findHandler(name)) {
      case null #err("unknown tool");
      case (?h) await h.run(args, deps);
    }
  };
}
