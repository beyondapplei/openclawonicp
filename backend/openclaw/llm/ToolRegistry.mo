import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import ToolWalletIcp "./ToolWalletIcp";
import ToolWalletEth "./ToolWalletEth";
import ToolTelegram "./ToolTelegram";
import ToolWalletBuyCkEth "./ToolWalletBuyCkEth";

module {
  public type ToolEntry = {
    spec : ToolTypes.ToolSpec;
    handler : ToolTypes.ToolHandler;
  };

  public let specs : [ToolTypes.ToolSpec] = [
    ToolWalletIcp.spec,
    ToolWalletEth.spec,
    ToolTelegram.spec,
    ToolWalletBuyCkEth.spec,
  ];

  public let entries : [ToolEntry] = [
    {
      spec = ToolWalletIcp.spec;
      handler = ToolWalletIcp.handler;
    },
    {
      spec = ToolWalletEth.spec;
      handler = ToolWalletEth.handler;
    },
    {
      spec = ToolTelegram.spec;
      handler = ToolTelegram.handler;
    },
    {
      spec = ToolWalletBuyCkEth.spec;
      handler = ToolWalletBuyCkEth.handler;
    },
  ];

  public func findHandler(name : Text) : ?ToolTypes.ToolHandler {
    for (entry in entries.vals()) {
      if (entry.handler.name == name) return ?entry.handler;
    };
    null
  };
}
