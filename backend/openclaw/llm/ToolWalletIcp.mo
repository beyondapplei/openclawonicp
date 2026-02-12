import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "wallet_send_icp";
    argsHint = "<to_principal>|<amount_e8s>";
    rule = "send ICP, 1 ICP = 100000000 e8s";
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 2) return #err("wallet_send_icp requires args: to_principal, amount_e8s");
    let toPrincipalText = Text.trim(args[0], #char ' ');
    let amountNat : Nat = switch (Nat.fromText(Text.trim(args[1], #char ' '))) {
      case null return #err("invalid amount_e8s");
      case (?v) v;
    };
    if (amountNat > 18_446_744_073_709_551_615) return #err("amount_e8s overflow nat64");
    let amountE8s : Nat64 = Nat64.fromNat(amountNat);
    if (Text.size(toPrincipalText) == 0 or amountE8s == 0) {
      return #err("invalid tool args");
    };

    switch (await deps.sendIcp(toPrincipalText, amountE8s)) {
      case (#ok(blockIndex)) #ok(Nat.toText(blockIndex));
      case (#err(e)) #err(e);
    }
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
