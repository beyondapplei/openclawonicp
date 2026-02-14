import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import RpcConfig "../wallet/RpcConfig";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "wallet_swap_uniswap";
    description = "Swap ERC20 on Uniswap V3 exactInputSingle. Supports optional auto approve.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"network\":{\"type\":\"string\",\"enum\":[\"ethereum\",\"base\",\"polygon\"]},\"router_address\":{\"type\":\"string\",\"description\":\"Uniswap V3 router address\"},\"token_in_address\":{\"type\":\"string\",\"description\":\"Input token address\"},\"token_out_address\":{\"type\":\"string\",\"description\":\"Output token address\"},\"fee\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Pool fee tier (500/3000/10000)\"},\"amount_in\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Input amount in base unit\"},\"amount_out_minimum\":{\"type\":\"integer\",\"minimum\":0,\"description\":\"Minimum output amount in base unit\"},\"deadline\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Optional unix seconds; default now + 1200\"},\"sqrt_price_limit_x96\":{\"type\":\"integer\",\"minimum\":0,\"description\":\"Optional; set 0 for no limit\"},\"auto_approve\":{\"type\":\"boolean\",\"description\":\"Optional; default true\"}},\"required\":[\"network\",\"router_address\",\"token_in_address\",\"token_out_address\",\"fee\",\"amount_in\",\"amount_out_minimum\"],\"additionalProperties\":false}";
    argNames = [
      "network",
      "router_address",
      "token_in_address",
      "token_out_address",
      "fee",
      "amount_in",
      "amount_out_minimum",
      "deadline",
      "sqrt_price_limit_x96",
      "auto_approve",
    ];
    permission = #owner;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 7) {
      return #err(
        "wallet_swap_uniswap requires args: network, router_address, token_in_address, token_out_address, fee, amount_in, amount_out_minimum",
      );
    };

    let network = RpcConfig.normalizeNetwork(args[0]);
    if (not RpcConfig.isSupported(network)) {
      return #err("network must be ethereum, base, or polygon");
    };

    let routerAddress = Text.trim(args[1], #char ' ');
    if (Text.size(routerAddress) == 0) return #err("invalid router_address");

    let tokenInAddress = Text.trim(args[2], #char ' ');
    if (Text.size(tokenInAddress) == 0) return #err("invalid token_in_address");

    let tokenOutAddress = Text.trim(args[3], #char ' ');
    if (Text.size(tokenOutAddress) == 0) return #err("invalid token_out_address");

    let fee = switch (parseNat(Text.trim(args[4], #char ' '), "fee")) {
      case (#err(e)) return #err(e);
      case (#ok(v)) v;
    };
    if (fee == 0 or fee > 16_777_215) return #err("fee must be in range 1..16777215");

    let amountIn = switch (parseNat(Text.trim(args[5], #char ' '), "amount_in")) {
      case (#err(e)) return #err(e);
      case (#ok(v)) v;
    };
    if (amountIn == 0) return #err("amount_in must be > 0");

    let amountOutMinimum = switch (parseNat(Text.trim(args[6], #char ' '), "amount_out_minimum")) {
      case (#err(e)) return #err(e);
      case (#ok(v)) v;
    };

    let nowSec = Int.abs(deps.nowNs()) / 1_000_000_000;
    let deadline = if (args.size() > 7 and Text.size(Text.trim(args[7], #char ' ')) > 0) {
      switch (parseNat(Text.trim(args[7], #char ' '), "deadline")) {
        case (#err(e)) return #err(e);
        case (#ok(v)) v;
      }
    } else {
      nowSec + 1_200
    };
    if (deadline <= nowSec) return #err("deadline must be in the future");

    let sqrtPriceLimitX96 = if (args.size() > 8 and Text.size(Text.trim(args[8], #char ' ')) > 0) {
      switch (parseNat(Text.trim(args[8], #char ' '), "sqrt_price_limit_x96")) {
        case (#err(e)) return #err(e);
        case (#ok(v)) v;
      }
    } else {
      0
    };

    let autoApprove = if (args.size() > 9 and Text.size(Text.trim(args[9], #char ' ')) > 0) {
      switch (parseBool(Text.trim(args[9], #char ' '))) {
        case null return #err("invalid auto_approve (true/false)");
        case (?v) v;
      }
    } else {
      true
    };

    switch (
      await deps.swapErc20Uniswap(
        network,
        routerAddress,
        tokenInAddress,
        tokenOutAddress,
        fee,
        amountIn,
        amountOutMinimum,
        deadline,
        sqrtPriceLimitX96,
        autoApprove,
      )
    ) {
      case (#ok(v)) #ok(v);
      case (#err(e)) #err(e);
    }
  };

  func parseNat(raw : Text, field : Text) : { #ok : Nat; #err : Text } {
    switch (Nat.fromText(raw)) {
      case null #err("invalid " # field);
      case (?v) #ok(v);
    }
  };

  func parseBool(raw : Text) : ?Bool {
    let t = Text.toLowercase(Text.trim(raw, #char ' '));
    if (t == "true" or t == "1" or t == "yes") return ?true;
    if (t == "false" or t == "0" or t == "no") return ?false;
    null
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
