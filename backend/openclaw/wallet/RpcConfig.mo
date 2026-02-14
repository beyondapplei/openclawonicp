import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Text "mo:base/Text";

module {
  // Canonical network names used by wallet send/balance APIs and tool validation.
  public let supportedNetworks : [Text] = ["ethereum", "base", "polygon"];
  // Reserved for future Solana wallet module.
  public let defaultSolanaRpcUrl : Text = "https://solana-rpc.publicnode.com";

  public func normalizeNetwork(network : Text) : Text {
    let n = Text.toLowercase(Text.trim(network, #char ' '));
    if (n == "eth" or n == "mainnet") {
      "ethereum"
    } else if (n == "matic") {
      "polygon"
    } else {
      n
    }
  };

  public func isSupported(network : Text) : Bool {
    switch (canonical(network)) {
      case null false;
      case (?_) true;
    }
  };

  public func chainId(network : Text) : ?Nat {
    switch (canonical(network)) {
      case (?"ethereum") ?1;
      case (?"base") ?8453;
      case (?"polygon") ?137;
      case null null;
      case (?_) null;
    }
  };

  public func defaultRpcUrl(network : Text) : ?Text {
    switch (canonical(network)) {
      case (?"ethereum") ? "https://ethereum-rpc.publicnode.com";
      case (?"base") ? "https://base-rpc.publicnode.com";
      case (?"polygon") ? "https://polygon-bor-rpc.publicnode.com";
      case null null;
      case (?_) null;
    }
  };

  public func effectiveRpcUrl(network : Text, rpcUrl : ?Text) : ?Text {
    switch (rpcUrl) {
      case (?u) {
        let t = Text.trim(u, #char ' ');
        if (Text.size(t) > 0) return ?t;
      };
      case null {};
    };
    defaultRpcUrl(network)
  };

  public func resolveRpcUrl(network : Text, rpcUrl : ?Text) : Result.Result<Text, Text> {
    switch (effectiveRpcUrl(network, rpcUrl)) {
      case (?u) #ok(u);
      case null #err("unsupported network: " # network);
    }
  };

  public func effectiveSolanaRpcUrl(rpcUrl : ?Text) : Text {
    switch (rpcUrl) {
      case (?u) {
        let t = Text.trim(u, #char ' ');
        if (Text.size(t) > 0) return t;
      };
      case null {};
    };
    defaultSolanaRpcUrl
  };

  func canonical(network : Text) : ?Text {
    let n = normalizeNetwork(network);
    if (n == "ethereum" or n == "base" or n == "polygon") {
      ?n
    } else {
      null
    }
  };
}
