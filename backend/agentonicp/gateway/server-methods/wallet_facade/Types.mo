import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import HttpTypes "../../../http/HttpTypes";
import Llm "../../../llm/Llm";
import Wallet "../../../wallet/Wallet";

module {
  public type WalletIcrc1Token = {
    symbol : Text;
    name : Text;
    ledgerPrincipalText : Text;
    decimals : Nat;
  };

  public type WalletEvmToken = {
    network : Text;
    symbol : Text;
    name : Text;
    tokenAddress : Text;
    decimals : Nat;
  };

  public type WalletNetworkInfo = {
    id : Text;
    kind : Text;
    name : Text;
    primarySymbol : Text;
    supportsSend : Bool;
    supportsBalance : Bool;
    defaultRpcUrl : ?Text;
  };

  public type WalletBalanceItem = {
    symbol : Text;
    name : Text;
    network : Text;
    decimals : Nat;
    amount : Nat;
    available : Bool;
    address : Text;
    error : ?Text;
    tokenAddress : ?Text;
    ledgerPrincipalText : ?Text;
  };

  public type WalletOverviewOut = {
    canisterPrincipal : Principal;
    canisterPrincipalText : Text;
    evmAddress : ?Text;
    selectedNetwork : Text;
    primarySymbol : Text;
    primaryAmount : Nat;
    primaryAvailable : Bool;
    balances : [WalletBalanceItem];
    icpLedgerUseMainnet : Bool;
  };

  public type WalletOverviewResult = Result.Result<WalletOverviewOut, Text>;

  public type WalletReceiveAddress = {
    kind : Text;
    address : Text;
  };

  public type WalletAssetDetailOut = {
    symbol : Text;
    name : Text;
    network : Text;
    decimals : Nat;
    amount : Nat;
    available : Bool;
    address : Text;
    error : ?Text;
    receiveAddresses : [WalletReceiveAddress];
    tokenAddress : ?Text;
    ledgerPrincipalText : ?Text;
  };

  public type WalletAssetDetailResult = Result.Result<WalletAssetDetailOut, Text>;

  public type WalletSendKind = {
    #icp;
    #icrc1;
    #eth;
    #erc20;
  };

  public type WalletSendRequest = {
    kind : WalletSendKind;
    network : ?Text;
    rpcUrl : ?Text;
    to : Text;
    amount : Nat;
    tokenAddress : ?Text;
    ledgerPrincipalText : ?Text;
    fee : ?Nat;
  };

  public type WalletSendOut = {
    kind : WalletSendKind;
    network : Text;
    txId : Text;
  };

  public type WalletSendResult = Result.Result<WalletSendOut, Text>;

  public type WalletHistoryDirection = {
    #incoming;
    #outgoing;
  };

  public type WalletHistoryItem = {
    network : Text;
    symbol : Text;
    blockIndex : Nat;
    txHash : Text;
    timestampNanos : Nat64;
    direction : WalletHistoryDirection;
    amount : Nat;
    fee : ?Nat;
    counterparty : ?Text;
    kind : Text;
  };

  public type WalletAssetHistoryResult = Result.Result<[WalletHistoryItem], Text>;
  public type WalletIcrc1TokenAddResult = Result.Result<WalletIcrc1Token, Text>;
  public type WalletEvmTokenAddResult = Result.Result<WalletEvmToken, Text>;

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
    icpLedgerUseMainnet : Bool;
    icrc1Tokens : [WalletIcrc1Token];
    evmTokens : [WalletEvmToken];
  };
}
