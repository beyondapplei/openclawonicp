import Nat "mo:base/Nat";
import Text "mo:base/Text";

import RpcConfig "./RpcConfig";

module {
  public type UniTradeConfig = {
    routerAddress : Text;
    quoterAddress : Text;
    uniAddress : Text;
    usdcAddress : Text;
    usdtAddress : Text;
    uniUsdcFee : Nat;
    uniUsdtFee : Nat;
    minEthGasReserveWei : Nat;
  };

  // Backend token/contract registry for automated UNI buy flow.
  // Currently enabled for Ethereum mainnet only.
  public func uniTradeConfig(network : Text) : ?UniTradeConfig {
    switch (RpcConfig.normalizeNetwork(network)) {
      case ("ethereum") {
        ?{
          // Uniswap V3 SwapRouter02 (Ethereum mainnet).
          routerAddress = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
          // Uniswap V3 Quoter (Ethereum mainnet).
          quoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";
          // Tokens
          uniAddress = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984";
          usdcAddress = "0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
          usdtAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
          // Typical UNI pools on mainnet.
          uniUsdcFee = 3_000;
          uniUsdtFee = 3_000;
          // Keep some ETH for gas.
          minEthGasReserveWei = 2_000_000_000_000_000; // 0.002 ETH
        }
      };
      case (_) null;
    }
  };

  public func tokenAddress(network : Text, symbol : Text) : ?Text {
    switch (uniTradeConfig(network)) {
      case null null;
      case (?cfg) {
        let s = Text.toUppercase(Text.trim(symbol, #char ' '));
        if (s == "UNI") return ?cfg.uniAddress;
        if (s == "USDC") return ?cfg.usdcAddress;
        if (s == "USDT") return ?cfg.usdtAddress;
        null
      }
    }
  };
}
