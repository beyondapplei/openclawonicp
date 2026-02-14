import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import HttpTypes "../../http/HttpTypes";
import Llm "../../llm/Llm";
import TokenConfig "../../wallet/TokenConfig";
import Wallet "../../wallet/Wallet";
import WalletEvm "../../wallet/WalletEvm";
import WalletIcp "../../wallet/WalletIcp";
import WalletMethods "./WalletMethods";

module {
  public type SendIcpResult = Result.Result<Nat, Text>;
  public type SendIcrc1Result = Result.Result<Nat, Text>;
  public type SendEthResult = Result.Result<Text, Text>;
  public type EthAddressResult = Result.Result<Text, Text>;
  public type BalanceResult = Result.Result<Nat, Text>;
  public type WalletResult = Wallet.WalletResult;
  public type EcdsaPublicKeyResult = Wallet.EcdsaPublicKeyResult;
  public type SignWithEcdsaResult = Wallet.SignWithEcdsaResult;

  public type Deps = {
    assertOwner : (caller : Principal) -> ();
    assertOwnerQuery : (caller : Principal) -> ();
    selfPrincipal : () -> Principal;
    effectiveRpcUrl : (network : Text, rpcUrl : ?Text) -> ?Text;
    ic : Llm.Http;
    ic00 : Wallet.Ic00;
    httpTransform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload;
    defaultHttpCycles : Nat;
    icpLedgerLocalPrincipal : Principal;
    icpLedgerMainnetPrincipal : Principal;
  };

  public func ecdsaPublicKey(
    deps : Deps,
    caller : Principal,
    derivationPath : [Blob],
    keyName : ?Text,
  ) : async EcdsaPublicKeyResult {
    await WalletMethods.ecdsaPublicKey(
      deps.assertOwner,
      caller,
      derivationPath,
      keyName,
      func(dp : [Blob], kn : ?Text) : async EcdsaPublicKeyResult {
        await WalletEvm.ecdsaPublicKey(deps.ic00, deps.selfPrincipal(), deps.selfPrincipal(), dp, kn)
      },
    )
  };

  public func signWithEcdsa(
    deps : Deps,
    caller : Principal,
    messageHash : Blob,
    derivationPath : [Blob],
    keyName : ?Text,
  ) : async SignWithEcdsaResult {
    await WalletMethods.signWithEcdsa(
      deps.assertOwner,
      caller,
      messageHash,
      derivationPath,
      keyName,
      func(mh : Blob, dp : [Blob], kn : ?Text) : async SignWithEcdsaResult {
        await WalletEvm.signWithEcdsa(deps.ic00, deps.selfPrincipal(), deps.selfPrincipal(), mh, dp, kn)
      },
    )
  };

  public func agentWallet(deps : Deps, caller : Principal) : async WalletResult {
    await WalletMethods.agentWallet(
      deps.assertOwner,
      caller,
      func() : async WalletResult {
        await WalletEvm.agentWallet(deps.ic00, deps.selfPrincipal(), deps.selfPrincipal())
      },
    )
  };

  public func canisterPrincipal(deps : Deps, caller : Principal) : Principal {
    WalletMethods.canisterPrincipal(deps.assertOwnerQuery, caller, deps.selfPrincipal())
  };

  public func sendIcp(
    deps : Deps,
    caller : Principal,
    toPrincipalText : Text,
    amountE8s : Nat64,
  ) : async SendIcpResult {
    await WalletMethods.sendIcp(
      deps.assertOwner,
      caller,
      toPrincipalText,
      amountE8s,
      func(toText : Text, amount : Nat64) : async SendIcpResult {
        await WalletIcp.sendIcp(deps.icpLedgerLocalPrincipal, deps.icpLedgerMainnetPrincipal, toText, amount)
      },
    )
  };

  public func sendIcrc1(
    deps : Deps,
    caller : Principal,
    ledgerPrincipalText : Text,
    toPrincipalText : Text,
    amount : Nat,
    fee : ?Nat,
  ) : async SendIcrc1Result {
    await WalletMethods.sendIcrc1(
      deps.assertOwner,
      caller,
      ledgerPrincipalText,
      toPrincipalText,
      amount,
      fee,
      func(lp : Text, toText : Text, amt : Nat, maybeFee : ?Nat) : async SendIcrc1Result {
        await WalletIcp.sendIcrc1(lp, toText, amt, maybeFee)
      },
    )
  };

  public func balanceIcp(deps : Deps, caller : Principal) : async BalanceResult {
    await WalletMethods.balanceIcp(
      deps.assertOwner,
      caller,
      func() : async BalanceResult {
        await WalletIcp.balanceIcp(deps.icpLedgerLocalPrincipal, deps.icpLedgerMainnetPrincipal, deps.selfPrincipal())
      },
    )
  };

  public func balanceIcrc1(
    deps : Deps,
    caller : Principal,
    ledgerPrincipalText : Text,
  ) : async BalanceResult {
    await WalletMethods.balanceIcrc1(
      deps.assertOwner,
      caller,
      ledgerPrincipalText,
      func(lp : Text) : async BalanceResult {
        await WalletIcp.balanceIcrc1(lp, deps.selfPrincipal())
      },
    )
  };

  public func sendEthRaw(
    deps : Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    rawTxHex : Text,
  ) : async SendEthResult {
    await WalletMethods.sendEthRaw(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      rawTxHex,
      func(net : Text, url : ?Text, raw : Text) : async SendEthResult {
        await WalletEvm.sendRaw(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          net,
          deps.effectiveRpcUrl(net, url),
          raw,
        )
      },
    )
  };

  public func ethAddressForCanister(deps : Deps) : async EthAddressResult {
    await WalletEvm.ethAddress(deps.ic00, deps.selfPrincipal(), deps.selfPrincipal())
  };

  public func ethAddress(deps : Deps, caller : Principal) : async EthAddressResult {
    deps.assertOwner(caller);
    await ethAddressForCanister(deps)
  };

  public func sendEth(
    deps : Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    toAddress : Text,
    amountWei : Nat,
  ) : async SendEthResult {
    await WalletMethods.sendEth(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      toAddress,
      amountWei,
      func(net : Text, url : ?Text, to : Text, amount : Nat) : async SendEthResult {
        await WalletEvm.send(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          deps.selfPrincipal(),
          deps.selfPrincipal(),
          net,
          deps.effectiveRpcUrl(net, url),
          to,
          amount,
        )
      },
    )
  };

  public func sendErc20(
    deps : Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    tokenAddress : Text,
    toAddress : Text,
    amount : Nat,
  ) : async SendEthResult {
    await WalletMethods.sendErc20(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      tokenAddress,
      toAddress,
      amount,
      func(net : Text, url : ?Text, token : Text, to : Text, amt : Nat) : async SendEthResult {
        await WalletEvm.sendErc20(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          deps.selfPrincipal(),
          deps.selfPrincipal(),
          net,
          deps.effectiveRpcUrl(net, url),
          token,
          to,
          amt,
        )
      },
    )
  };

  public func buyErc20Uniswap(
    deps : Deps,
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
  ) : async SendEthResult {
    await WalletMethods.buyErc20Uniswap(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      routerAddress,
      tokenInAddress,
      tokenOutAddress,
      fee,
      amountIn,
      amountOutMinimum,
      deadline,
      sqrtPriceLimitX96,
      func(
        net : Text,
        url : ?Text,
        router : Text,
        tokenIn : Text,
        tokenOut : Text,
        poolFee : Nat,
        amountInBase : Nat,
        amountOutMinBase : Nat,
        deadlineSec : Nat,
        sqrtLimit : Nat,
      ) : async SendEthResult {
        await WalletEvm.buyErc20Uniswap(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          deps.selfPrincipal(),
          deps.selfPrincipal(),
          net,
          deps.effectiveRpcUrl(net, url),
          router,
          tokenIn,
          tokenOut,
          poolFee,
          amountInBase,
          amountOutMinBase,
          deadlineSec,
          sqrtLimit,
        )
      },
    )
  };

  public func swapErc20Uniswap(
    deps : Deps,
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
  ) : async SendEthResult {
    await WalletMethods.swapErc20Uniswap(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      routerAddress,
      tokenInAddress,
      tokenOutAddress,
      fee,
      amountIn,
      amountOutMinimum,
      deadline,
      sqrtPriceLimitX96,
      autoApprove,
      func(
        net : Text,
        url : ?Text,
        router : Text,
        tokenIn : Text,
        tokenOut : Text,
        poolFee : Nat,
        amountInBase : Nat,
        amountOutMinBase : Nat,
        deadlineSec : Nat,
        sqrtLimit : Nat,
        doAutoApprove : Bool,
      ) : async SendEthResult {
        await WalletEvm.swapErc20Uniswap(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          deps.selfPrincipal(),
          deps.selfPrincipal(),
          net,
          deps.effectiveRpcUrl(net, url),
          router,
          tokenIn,
          tokenOut,
          poolFee,
          amountInBase,
          amountOutMinBase,
          deadlineSec,
          sqrtLimit,
          doAutoApprove,
        )
      },
    )
  };

  public func buyUni(
    deps : Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    amountUniBase : Nat,
    slippageBps : Nat,
    deadline : Nat,
  ) : async SendEthResult {
    await WalletMethods.buyUniAuto(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      amountUniBase,
      slippageBps,
      deadline,
      func(
        net : Text,
        url : ?Text,
        amountUni : Nat,
        slippage : Nat,
        deadlineSec : Nat,
      ) : async SendEthResult {
        await WalletEvm.buyUniAuto(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          deps.selfPrincipal(),
          deps.selfPrincipal(),
          net,
          deps.effectiveRpcUrl(net, url),
          amountUni,
          slippage,
          deadlineSec,
        )
      },
    )
  };

  public func tokenAddress(
    deps : Deps,
    caller : Principal,
    network : Text,
    symbol : Text,
  ) : ?Text {
    deps.assertOwnerQuery(caller);
    TokenConfig.tokenAddress(network, symbol)
  };

  public func balanceEth(
    deps : Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
  ) : async BalanceResult {
    await WalletMethods.balanceEth(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      func(net : Text, url : ?Text) : async BalanceResult {
        await WalletEvm.balanceEth(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          deps.selfPrincipal(),
          deps.selfPrincipal(),
          net,
          deps.effectiveRpcUrl(net, url),
        )
      },
    )
  };

  public func balanceErc20(
    deps : Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    tokenAddress : Text,
  ) : async BalanceResult {
    await WalletMethods.balanceErc20(
      deps.assertOwner,
      caller,
      network,
      rpcUrl,
      tokenAddress,
      func(net : Text, url : ?Text, token : Text) : async BalanceResult {
        await WalletEvm.balanceErc20(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          deps.selfPrincipal(),
          deps.selfPrincipal(),
          net,
          deps.effectiveRpcUrl(net, url),
          token,
        )
      },
    )
  };
}
