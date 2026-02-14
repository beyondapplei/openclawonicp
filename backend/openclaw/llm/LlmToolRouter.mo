import Buffer "mo:base/Buffer";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import ToolPolicy "./ToolPolicy";
import ToolRegistry "./ToolRegistry";

module {
  public type ToolResult = ToolTypes.ToolResult;
  public type SendIcpFn = ToolTypes.SendIcpFn;
  public type SendEthFn = ToolTypes.SendEthFn;
  public type SendErc20Fn = ToolTypes.SendErc20Fn;
  public type BuyErc20UniswapFn = ToolTypes.BuyErc20UniswapFn;
  public type SwapErc20UniswapFn = ToolTypes.SwapErc20UniswapFn;
  public type BuyUniFn = ToolTypes.BuyUniFn;
  public type PolymarketResearchFn = ToolTypes.PolymarketResearchFn;
  public type SendTgFn = ToolTypes.SendTgFn;
  public type BuyCkEthFn = ToolTypes.BuyCkEthFn;
  public type KvGetFn = ToolTypes.KvGetFn;
  public type KvPutFn = ToolTypes.KvPutFn;
  public type NowNsFn = ToolTypes.NowNsFn;
  public type ToolSpec = ToolTypes.ToolSpec;
  public type Surface = { #llm; #api };
  public type ToolFilter = ToolPolicy.ToolFilter;
  public type ToolProfile = ToolPolicy.ToolProfile;
  type DispatchDeps = ToolTypes.DispatchDeps;

  public func listSpecs(surface : Surface, includeOwnerTools : Bool, filter : ?ToolFilter) : [ToolSpec] {
    let out = Buffer.Buffer<ToolSpec>(ToolRegistry.entries.size());
    for (entry in ToolRegistry.entries.vals()) {
      if (isVisible(entry.spec, surface, includeOwnerTools, filter)) {
        out.add(entry.spec);
      };
    };
    Buffer.toArray(out)
  };

  public func listToolNames(surface : Surface, includeOwnerTools : Bool, filter : ?ToolFilter) : [Text] {
    let specs = listSpecs(surface, includeOwnerTools, filter);
    let out = Buffer.Buffer<Text>(specs.size());
    for (s in specs.vals()) out.add(s.name);
    Buffer.toArray(out)
  };

  public func dispatch(
    surface : Surface,
    includeOwnerTools : Bool,
    filter : ?ToolFilter,
    name : Text,
    args : [Text],
    sendIcp : SendIcpFn,
    sendEth : SendEthFn,
    sendErc20 : SendErc20Fn,
    buyErc20Uniswap : BuyErc20UniswapFn,
    swapErc20Uniswap : SwapErc20UniswapFn,
    buyUni : BuyUniFn,
    polymarketResearch : PolymarketResearchFn,
    sendTg : SendTgFn,
    buyCkEth : BuyCkEthFn,
    kvGet : KvGetFn,
    kvPut : KvPutFn,
    nowNs : NowNsFn,
  ) : async ToolResult {
    let deps : DispatchDeps = {
      sendIcp = sendIcp;
      sendEth = sendEth;
      sendErc20 = sendErc20;
      buyErc20Uniswap = buyErc20Uniswap;
      swapErc20Uniswap = swapErc20Uniswap;
      buyUni = buyUni;
      polymarketResearch = polymarketResearch;
      sendTg = sendTg;
      buyCkEth = buyCkEth;
      kvGet = kvGet;
      kvPut = kvPut;
      nowNs = nowNs;
    };

    switch (ToolRegistry.findEntry(name)) {
      case null #err("unknown tool");
      case (?entry) {
        if (not isVisible(entry.spec, surface, includeOwnerTools, filter)) {
          return #err("tool not allowed");
        };
        await entry.handler.run(args, deps)
      };
    }
  };

  func isVisible(spec : ToolSpec, surface : Surface, includeOwnerTools : Bool, filter : ?ToolFilter) : Bool {
    if (not hasPermission(spec.permission, includeOwnerTools)) return false;
    if (not ToolPolicy.isAllowed(spec.name, filter)) return false;
    switch (surface) {
      case (#llm) spec.exposeToLlm;
      case (#api) spec.exposeToApi;
    }
  };

  func hasPermission(permission : ToolTypes.ToolPermission, includeOwnerTools : Bool) : Bool {
    switch (permission) {
      case (#user) true;
      case (#owner) includeOwnerTools;
    }
  };
}
