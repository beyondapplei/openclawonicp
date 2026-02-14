import Nat "mo:base/Nat";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";
import RpcConfig "../wallet/RpcConfig";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "wallet_send_erc20";
    description = "Send ERC20 token on ethereum/base/polygon from the agent wallet.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"network\":{\"type\":\"string\",\"enum\":[\"ethereum\",\"base\",\"polygon\"]},\"token_address\":{\"type\":\"string\",\"description\":\"ERC20 token contract address\"},\"to_address\":{\"type\":\"string\",\"description\":\"Destination EVM address\"},\"amount\":{\"type\":\"integer\",\"minimum\":1,\"description\":\"Token amount in base unit\"}},\"required\":[\"network\",\"token_address\",\"to_address\",\"amount\"],\"additionalProperties\":false}";
    argNames = ["network", "token_address", "to_address", "amount"];
    permission = #owner;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 4) return #err("wallet_send_erc20 requires args: network, token_address, to_address, amount");

    let network = RpcConfig.normalizeNetwork(args[0]);
    if (not RpcConfig.isSupported(network)) {
      return #err("network must be ethereum, base, or polygon");
    };

    let tokenAddress = Text.trim(args[1], #char ' ');
    if (Text.size(tokenAddress) == 0) return #err("invalid token_address");

    let toAddress = Text.trim(args[2], #char ' ');
    if (Text.size(toAddress) == 0) return #err("invalid to_address");

    let amount : Nat = switch (Nat.fromText(Text.trim(args[3], #char ' '))) {
      case null return #err("invalid amount");
      case (?v) v;
    };
    if (amount == 0) return #err("amount must be > 0");

    switch (await deps.sendErc20(network, tokenAddress, toAddress, amount)) {
      case (#ok(txHash)) #ok(txHash);
      case (#err(e)) #err(e);
    }
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
