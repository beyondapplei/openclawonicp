import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import ToolKvGet "./ToolKvGet";
import ToolKvPut "./ToolKvPut";
import ToolTimeNowNs "./ToolTimeNowNs";
import ToolWalletIcp "./ToolWalletIcp";
import ToolWalletEth "./ToolWalletEth";
import ToolWalletErc20 "./ToolWalletErc20";
import ToolWalletBuyErc20Uniswap "./ToolWalletBuyErc20Uniswap";
import ToolWalletSwapUniswap "./ToolWalletSwapUniswap";
import ToolWalletBuyUni "./ToolWalletBuyUni";
import ToolPolymarketResearch "./ToolPolymarketResearch";
import ToolTelegram "./ToolTelegram";
import ToolWalletBuyCkEth "./ToolWalletBuyCkEth";

module {
  public type ToolEntry = {
    spec : ToolTypes.ToolSpec;
    handler : ToolTypes.ToolHandler;
  };

  public let specs : [ToolTypes.ToolSpec] = [
    ToolKvGet.spec,
    ToolKvPut.spec,
    ToolTimeNowNs.spec,
    ToolWalletIcp.spec,
    ToolWalletEth.spec,
    ToolWalletErc20.spec,
    ToolWalletBuyErc20Uniswap.spec,
    ToolWalletSwapUniswap.spec,
    ToolWalletBuyUni.spec,
    ToolPolymarketResearch.spec,
    ToolTelegram.spec,
    ToolWalletBuyCkEth.spec,
  ];

  public let entries : [ToolEntry] = [
    {
      spec = ToolKvGet.spec;
      handler = ToolKvGet.handler;
    },
    {
      spec = ToolKvPut.spec;
      handler = ToolKvPut.handler;
    },
    {
      spec = ToolTimeNowNs.spec;
      handler = ToolTimeNowNs.handler;
    },
    {
      spec = ToolWalletIcp.spec;
      handler = ToolWalletIcp.handler;
    },
    {
      spec = ToolWalletEth.spec;
      handler = ToolWalletEth.handler;
    },
    {
      spec = ToolWalletErc20.spec;
      handler = ToolWalletErc20.handler;
    },
    {
      spec = ToolWalletBuyErc20Uniswap.spec;
      handler = ToolWalletBuyErc20Uniswap.handler;
    },
    {
      spec = ToolWalletSwapUniswap.spec;
      handler = ToolWalletSwapUniswap.handler;
    },
    {
      spec = ToolWalletBuyUni.spec;
      handler = ToolWalletBuyUni.handler;
    },
    {
      spec = ToolPolymarketResearch.spec;
      handler = ToolPolymarketResearch.handler;
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

  public func findEntry(name : Text) : ?ToolEntry {
    let target = normalize(name);
    for (entry in entries.vals()) {
      if (normalize(entry.handler.name) == target) return ?entry;
    };
    null
  };

  func normalize(v : Text) : Text {
    Text.toLowercase(Text.trim(v, #char ' '))
  };
}
