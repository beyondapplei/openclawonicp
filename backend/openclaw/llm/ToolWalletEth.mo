import Nat "mo:base/Nat";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "wallet_send_eth";
    argsHint = "<network>|<to_address>|<amount_wei>";
    rule = "network is ethereum or base";
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 3) return #err("wallet_send_eth requires args: network, to_address, amount_wei");
    let network = Text.toLowercase(Text.trim(args[0], #char ' '));
    if (network != "ethereum" and network != "base") {
      return #err("network must be ethereum or base");
    };
    let toAddress = Text.trim(args[1], #char ' ');
    if (Text.size(toAddress) == 0) return #err("invalid to_address");

    let amountWei : Nat = switch (Nat.fromText(Text.trim(args[2], #char ' '))) {
      case null return #err("invalid amount_wei");
      case (?v) v;
    };
    if (amountWei == 0) return #err("amount_wei must be > 0");

    switch (await deps.sendEth(network, toAddress, amountWei)) {
      case (#ok(txHash)) #ok(txHash);
      case (#err(e)) #err(e);
    }
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
