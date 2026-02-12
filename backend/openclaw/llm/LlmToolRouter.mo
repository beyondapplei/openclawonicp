import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import ToolWalletIcp "./ToolWalletIcp";
import ToolWalletEth "./ToolWalletEth";
import ToolTelegram "./ToolTelegram";
import ToolWalletBuyCkEth "./ToolWalletBuyCkEth";

module {
  public type ToolResult = ToolTypes.ToolResult;
  public type SendIcpFn = ToolTypes.SendIcpFn;
  public type SendEthFn = ToolTypes.SendEthFn;
  public type SendTgFn = ToolTypes.SendTgFn;
  public type BuyCkEthFn = ToolTypes.BuyCkEthFn;
  public type ToolSpec = ToolTypes.ToolSpec;
  type DispatchDeps = ToolTypes.DispatchDeps;
  type ToolHandler = ToolTypes.ToolHandler;

  public let defaultSpecs : [ToolSpec] = [
    ToolWalletIcp.spec,
    ToolWalletEth.spec,
    ToolTelegram.spec,
    ToolWalletBuyCkEth.spec,
  ];

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
    switch (findHandler(name)) {
      case null #err("unknown tool");
      case (?h) await h.run(args, deps);
    }
  };

  let handlers : [ToolHandler] = [
    ToolWalletIcp.handler,
    ToolWalletEth.handler,
    ToolTelegram.handler,
    ToolWalletBuyCkEth.handler,
  ];

  func findHandler(name : Text) : ?ToolHandler {
    for (h in handlers.vals()) {
      if (h.name == name) return ?h;
    };
    null
  };
}
