import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import RpcConfig "../wallet/RpcConfig";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "wallet_send_eth";
    description = "Send native token on ethereum/base/polygon from the agent wallet. Provide either amount_wei or amount_eth.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"network\":{\"type\":\"string\",\"enum\":[\"ethereum\",\"base\",\"polygon\"]},\"to_address\":{\"type\":\"string\",\"description\":\"Hex EVM address\"},\"amount_wei\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Amount in wei (use only if caller already provides wei)\"},\"amount_eth\":{\"type\":\"string\",\"description\":\"Preferred for user intents; human-readable amount text, e.g. 2 or 0.1\"}},\"required\":[\"network\",\"to_address\"],\"oneOf\":[{\"required\":[\"amount_wei\"]},{\"required\":[\"amount_eth\"]}],\"additionalProperties\":false}";
    argNames = ["network", "to_address", "amount_wei", "amount_eth"];
    permission = #owner;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 3) return #err("wallet_send_eth requires args: network, to_address, amount_wei|amount_eth");
    let network = RpcConfig.normalizeNetwork(args[0]);
    if (not RpcConfig.isSupported(network)) {
      return #err("network must be ethereum, base, or polygon");
    };
    let toAddress = Text.trim(args[1], #char ' ');
    if (Text.size(toAddress) == 0) return #err("invalid to_address");

    let amountWeiText = Text.trim(args[2], #char ' ');
    let amountEthText = if (args.size() > 3) { Text.trim(args[3], #char ' ') } else { "" };
    if (Text.size(amountWeiText) > 0 and Text.size(amountEthText) > 0) {
      return #err("provide either amount_wei or amount_eth, not both");
    };

    let amountWei : Nat = if (Text.size(amountWeiText) > 0) {
      switch (Nat.fromText(amountWeiText)) {
        case null return #err("invalid amount_wei");
        case (?v) v;
      }
    } else {
      switch (parseAmountEthToWei(amountEthText)) {
        case null return #err("invalid amount_eth, expected decimal text up to 18 decimals");
        case (?v) v;
      }
    };
    if (amountWei == 0) return #err("amount_wei must be > 0");

    switch (await deps.sendEth(network, toAddress, amountWei)) {
      case (#ok(txHash)) #ok(txHash);
      case (#err(e)) #err(e);
    }
  };

  func parseAmountEthToWei(rawText : Text) : ?Nat {
    let text = Text.trim(rawText, #char ' ');
    if (Text.size(text) == 0) return null;

    let parts = Text.split(text, #char '.');
    let wholePart = switch (parts.next()) {
      case null return null;
      case (?v) v;
    };
    let fracOpt = parts.next();
    if (parts.next() != null) return null;

    let whole = switch (parseDigitsOrEmpty(wholePart, true)) {
      case null return null;
      case (?v) v;
    };

    let fracAndPad = switch (fracOpt) {
      case null ?0;
      case (?f) {
        if (Text.size(f) > 18) return null;
        let frac = switch (parseDigitsOrEmpty(f, false)) {
          case null return null;
          case (?v) v;
        };
        ?(frac * pow10(18 - Text.size(f)))
      };
    };

    switch (fracAndPad) {
      case null null;
      case (?fracWei) ?(whole * pow10(18) + fracWei);
    }
  };

  func parseDigitsOrEmpty(text : Text, allowEmpty : Bool) : ?Nat {
    if (Text.size(text) == 0) {
      if (allowEmpty) return ?0 else return null;
    };
    var acc : Nat = 0;
    for (c in text.chars()) {
      if (c < '0' or c > '9') return null;
      let d = Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
      acc := acc * 10 + d;
    };
    ?acc
  };

  func pow10(n : Nat) : Nat {
    var v : Nat = 1;
    var i : Nat = 0;
    while (i < n) {
      v *= 10;
      i += 1;
    };
    v
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
