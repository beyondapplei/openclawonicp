import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "wallet_buy_cketh";
    description = "Buy ckETH by comparing ICPSwap/KongSwap quotes and choosing cheaper venue.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"amount_cketh\":{\"type\":\"string\",\"description\":\"ckETH amount text, e.g. 0.5\"},\"max_icp_e8s\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Max ICP in e8s\"}},\"required\":[\"amount_cketh\",\"max_icp_e8s\"],\"additionalProperties\":false}";
    argNames = ["amount_cketh", "max_icp_e8s"];
    permission = #owner;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 2) return #err("wallet_buy_cketh requires args: amount_cketh, max_icp_e8s");

    let amountCkEthText = Text.trim(args[0], #char ' ');
    if (Text.size(amountCkEthText) == 0) return #err("invalid amount_cketh");

    let maxIcpNat : Nat = switch (Nat.fromText(Text.trim(args[1], #char ' '))) {
      case null return #err("invalid max_icp_e8s");
      case (?v) v;
    };
    if (maxIcpNat == 0) return #err("max_icp_e8s must be > 0");
    if (maxIcpNat > 18_446_744_073_709_551_615) return #err("max_icp_e8s overflow nat64");

    let maxIcpE8s : Nat64 = Nat64.fromNat(maxIcpNat);
    switch (await deps.buyCkEth(amountCkEthText, maxIcpE8s)) {
      case (#ok(v)) #ok(v);
      case (#err(e)) #err(e);
    }
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
