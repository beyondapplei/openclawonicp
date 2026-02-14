import Char "mo:base/Char";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import RpcConfig "../wallet/RpcConfig";
import TokenConfig "../wallet/TokenConfig";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "wallet_buy_uni";
    description = "Buy UNI token using Uniswap V3. Backend checks ETH gas balance + USDC/USDT balance, auto-selects input token, quotes, approves if needed, then swaps.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"network\":{\"type\":\"string\",\"enum\":[\"ethereum\"]},\"amount_uni\":{\"type\":\"string\",\"description\":\"UNI amount text, e.g. 2 or 2.5\"},\"slippage_bps\":{\"type\":\"integer\",\"minimum\":0,\"maximum\":5000,\"description\":\"Optional, default 100 = 1%\"},\"deadline\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Optional unix seconds, default now + 1200\"}},\"required\":[\"network\",\"amount_uni\"],\"additionalProperties\":false}";
    argNames = ["network", "amount_uni", "slippage_bps", "deadline"];
    permission = #owner;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 2) return #err("wallet_buy_uni requires args: network, amount_uni");

    let network = RpcConfig.normalizeNetwork(args[0]);
    if (TokenConfig.uniTradeConfig(network) == null) {
      return #err("wallet_buy_uni currently supports ethereum");
    };

    let amountUniBase = switch (parseAmountToBaseUnits(Text.trim(args[1], #char ' '), 18)) {
      case null return #err("invalid amount_uni");
      case (?v) v;
    };
    if (amountUniBase == 0) return #err("amount_uni must be > 0");

    let slippageBps = if (args.size() > 2 and Text.size(Text.trim(args[2], #char ' ')) > 0) {
      switch (Nat.fromText(Text.trim(args[2], #char ' '))) {
        case null return #err("invalid slippage_bps");
        case (?v) v;
      }
    } else {
      100
    };
    if (slippageBps > 5_000) return #err("slippage_bps must be <= 5000");

    let nowSec = Int.abs(deps.nowNs()) / 1_000_000_000;
    let deadline = if (args.size() > 3 and Text.size(Text.trim(args[3], #char ' ')) > 0) {
      switch (Nat.fromText(Text.trim(args[3], #char ' '))) {
        case null return #err("invalid deadline");
        case (?v) v;
      }
    } else {
      nowSec + 1_200
    };
    if (deadline <= nowSec) return #err("deadline must be in the future");

    switch (await deps.buyUni(network, amountUniBase, slippageBps, deadline)) {
      case (#ok(v)) #ok(v);
      case (#err(e)) #err(e);
    }
  };

  func parseAmountToBaseUnits(rawText : Text, decimals : Nat) : ?Nat {
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
        if (Text.size(f) > decimals) return null;
        let frac = switch (parseDigitsOrEmpty(f, false)) {
          case null return null;
          case (?v) v;
        };
        ?(frac * pow10(decimals - Text.size(f)))
      };
    };

    switch (fracAndPad) {
      case null null;
      case (?fracBase) ?(whole * pow10(decimals) + fracBase);
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
