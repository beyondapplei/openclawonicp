import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import EthTx "./EthTx";
import HttpTypes "../http/HttpTypes";
import Llm "../llm/Llm";
import Wallet "./Wallet";

module {
  public type SendEthResult = Result.Result<Text, Text>;
  public type EthAddressResult = Result.Result<Text, Text>;
  public type BalanceResult = Result.Result<Nat, Text>;
  public type EcdsaPublicKeyResult = Wallet.EcdsaPublicKeyResult;
  public type SignWithEcdsaResult = Wallet.SignWithEcdsaResult;
  public type WalletResult = Wallet.WalletResult;

  public func ecdsaPublicKey(
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
    derivationPath : [Blob],
    keyName : ?Text,
  ) : async EcdsaPublicKeyResult {
    await Wallet.ecdsaPublicKey(ic00, caller, canisterId, derivationPath, keyName)
  };

  public func signWithEcdsa(
    ic00 : Wallet.Ic00,
    caller : Principal,
    messageHash : Blob,
    derivationPath : [Blob],
    keyName : ?Text,
  ) : async SignWithEcdsaResult {
    await Wallet.signWithEcdsa(ic00, caller, messageHash, derivationPath, keyName)
  };

  public func agentWallet(
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
  ) : async WalletResult {
    await Wallet.agentWallet(ic00, caller, canisterId)
  };

  public func ethAddress(
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
  ) : async EthAddressResult {
    await EthTx.ethAddress(ic00, caller, canisterId)
  };

  public func sendRaw(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    network : Text,
    rpcUrl : ?Text,
    rawTxHex : Text,
  ) : async SendEthResult {
    await EthTx.sendRaw(ic, transform, httpCycles, network, rpcUrl, rawTxHex)
  };

  public func send(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
    network : Text,
    rpcUrl : ?Text,
    toAddress : Text,
    amountWei : Nat,
  ) : async SendEthResult {
    await EthTx.send(ic, transform, httpCycles, ic00, caller, canisterId, network, rpcUrl, toAddress, amountWei)
  };

  public func sendErc20(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
    network : Text,
    rpcUrl : ?Text,
    tokenAddress : Text,
    toAddress : Text,
    amount : Nat,
  ) : async SendEthResult {
    await EthTx.sendErc20(ic, transform, httpCycles, ic00, caller, canisterId, network, rpcUrl, tokenAddress, toAddress, amount)
  };

  public func balanceEth(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
    network : Text,
    rpcUrl : ?Text,
  ) : async BalanceResult {
    await EthTx.balanceEth(ic, transform, httpCycles, ic00, caller, canisterId, network, rpcUrl)
  };

  public func balanceErc20(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
    network : Text,
    rpcUrl : ?Text,
    tokenAddress : Text,
  ) : async BalanceResult {
    await EthTx.balanceErc20(ic, transform, httpCycles, ic00, caller, canisterId, network, rpcUrl, tokenAddress)
  };
}
