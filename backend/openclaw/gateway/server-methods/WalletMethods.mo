import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import Wallet "../../wallet/Wallet";

module {
  public func ecdsaPublicKey(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    derivationPath : [Blob],
    keyName : ?Text,
    run : (derivationPath : [Blob], keyName : ?Text) -> async Wallet.EcdsaPublicKeyResult,
  ) : async Wallet.EcdsaPublicKeyResult {
    assertOwner(caller);
    await run(derivationPath, keyName)
  };

  public func signWithEcdsa(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    messageHash : Blob,
    derivationPath : [Blob],
    keyName : ?Text,
    run : (
      messageHash : Blob,
      derivationPath : [Blob],
      keyName : ?Text,
    ) -> async Wallet.SignWithEcdsaResult,
  ) : async Wallet.SignWithEcdsaResult {
    assertOwner(caller);
    await run(messageHash, derivationPath, keyName)
  };

  public func agentWallet(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    run : () -> async Wallet.WalletResult,
  ) : async Wallet.WalletResult {
    assertOwner(caller);
    await run()
  };

  public func canisterPrincipal(
    assertOwnerQuery : (caller : Principal) -> (),
    caller : Principal,
    canisterPrincipal : Principal,
  ) : Principal {
    assertOwnerQuery(caller);
    canisterPrincipal
  };

  public func sendIcp(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    toPrincipalText : Text,
    amountE8s : Nat64,
    run : (toPrincipalText : Text, amountE8s : Nat64) -> async Result.Result<Nat, Text>,
  ) : async Result.Result<Nat, Text> {
    assertOwner(caller);
    await run(toPrincipalText, amountE8s)
  };

  public func sendIcrc1(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    ledgerPrincipalText : Text,
    toPrincipalText : Text,
    amount : Nat,
    fee : ?Nat,
    run : (ledgerPrincipalText : Text, toPrincipalText : Text, amount : Nat, fee : ?Nat) -> async Result.Result<Nat, Text>,
  ) : async Result.Result<Nat, Text> {
    assertOwner(caller);
    await run(ledgerPrincipalText, toPrincipalText, amount, fee)
  };

  public func balanceIcp(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    run : () -> async Result.Result<Nat, Text>,
  ) : async Result.Result<Nat, Text> {
    assertOwner(caller);
    await run()
  };

  public func balanceIcrc1(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    ledgerPrincipalText : Text,
    run : (ledgerPrincipalText : Text) -> async Result.Result<Nat, Text>,
  ) : async Result.Result<Nat, Text> {
    assertOwner(caller);
    await run(ledgerPrincipalText)
  };

  public func sendEthRaw(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    rawTxHex : Text,
    run : (network : Text, rpcUrl : ?Text, rawTxHex : Text) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    await run(network, rpcUrl, rawTxHex)
  };

  public func ethAddress(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    run : () -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    await run()
  };

  public func sendEth(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    toAddress : Text,
    amountWei : Nat,
    run : (network : Text, rpcUrl : ?Text, toAddress : Text, amountWei : Nat) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    await run(network, rpcUrl, toAddress, amountWei)
  };

  public func sendErc20(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    tokenAddress : Text,
    toAddress : Text,
    amount : Nat,
    run : (
      network : Text,
      rpcUrl : ?Text,
      tokenAddress : Text,
      toAddress : Text,
      amount : Nat,
    ) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    await run(network, rpcUrl, tokenAddress, toAddress, amount)
  };

  public func buyErc20Uniswap(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    routerAddress : Text,
    tokenInAddress : Text,
    tokenOutAddress : Text,
    fee : Nat,
    amountIn : Nat,
    amountOutMinimum : Nat,
    deadline : Nat,
    sqrtPriceLimitX96 : Nat,
    run : (
      network : Text,
      rpcUrl : ?Text,
      routerAddress : Text,
      tokenInAddress : Text,
      tokenOutAddress : Text,
      fee : Nat,
      amountIn : Nat,
      amountOutMinimum : Nat,
      deadline : Nat,
      sqrtPriceLimitX96 : Nat,
    ) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    if (fee == 0) return #err("fee must be > 0");
    if (amountIn == 0) return #err("amountIn must be > 0");
    await run(network, rpcUrl, routerAddress, tokenInAddress, tokenOutAddress, fee, amountIn, amountOutMinimum, deadline, sqrtPriceLimitX96)
  };

  public func swapErc20Uniswap(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    routerAddress : Text,
    tokenInAddress : Text,
    tokenOutAddress : Text,
    fee : Nat,
    amountIn : Nat,
    amountOutMinimum : Nat,
    deadline : Nat,
    sqrtPriceLimitX96 : Nat,
    autoApprove : Bool,
    run : (
      network : Text,
      rpcUrl : ?Text,
      routerAddress : Text,
      tokenInAddress : Text,
      tokenOutAddress : Text,
      fee : Nat,
      amountIn : Nat,
      amountOutMinimum : Nat,
      deadline : Nat,
      sqrtPriceLimitX96 : Nat,
      autoApprove : Bool,
    ) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    if (fee == 0) return #err("fee must be > 0");
    if (amountIn == 0) return #err("amountIn must be > 0");
    if (deadline == 0) return #err("deadline must be > 0");
    await run(network, rpcUrl, routerAddress, tokenInAddress, tokenOutAddress, fee, amountIn, amountOutMinimum, deadline, sqrtPriceLimitX96, autoApprove)
  };

  public func buyUniAuto(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    amountUniBase : Nat,
    slippageBps : Nat,
    deadline : Nat,
    run : (
      network : Text,
      rpcUrl : ?Text,
      amountUniBase : Nat,
      slippageBps : Nat,
      deadline : Nat,
    ) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    if (amountUniBase == 0) return #err("amountUniBase must be > 0");
    if (deadline == 0) return #err("deadline must be > 0");
    await run(network, rpcUrl, amountUniBase, slippageBps, deadline)
  };

  public func buyCkEthOne(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    maxIcpE8s : Nat64,
    run : (maxIcpE8s : Nat64) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    if (maxIcpE8s == 0) return #err("maxIcpE8s must be > 0");
    await run(maxIcpE8s)
  };

  public func buyCkEth(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    amountCkEthText : Text,
    maxIcpE8s : Nat64,
    run : (amountCkEthText : Text, maxIcpE8s : Nat64) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    if (maxIcpE8s == 0) return #err("maxIcpE8s must be > 0");
    await run(amountCkEthText, maxIcpE8s)
  };

  public func balanceEth(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    run : (network : Text, rpcUrl : ?Text) -> async Result.Result<Nat, Text>,
  ) : async Result.Result<Nat, Text> {
    assertOwner(caller);
    await run(network, rpcUrl)
  };

  public func balanceErc20(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    tokenAddress : Text,
    run : (network : Text, rpcUrl : ?Text, tokenAddress : Text) -> async Result.Result<Nat, Text>,
  ) : async Result.Result<Nat, Text> {
    assertOwner(caller);
    await run(network, rpcUrl, tokenAddress)
  };
}
