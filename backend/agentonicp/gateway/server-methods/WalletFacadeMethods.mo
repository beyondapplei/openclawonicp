import Principal "mo:base/Principal";

import History "./wallet_facade/History";
import Networks "./wallet_facade/Networks";
import Overview "./wallet_facade/Overview";
import Send "./wallet_facade/Send";
import Types "./wallet_facade/Types";

module {
  public type WalletIcrc1Token = Types.WalletIcrc1Token;
  public type WalletEvmToken = Types.WalletEvmToken;
  public type WalletNetworkInfo = Types.WalletNetworkInfo;
  public type WalletBalanceItem = Types.WalletBalanceItem;
  public type WalletOverviewOut = Types.WalletOverviewOut;
  public type WalletOverviewResult = Types.WalletOverviewResult;
  public type WalletReceiveAddress = Types.WalletReceiveAddress;
  public type WalletAssetDetailOut = Types.WalletAssetDetailOut;
  public type WalletAssetDetailResult = Types.WalletAssetDetailResult;
  public type WalletSendKind = Types.WalletSendKind;
  public type WalletSendRequest = Types.WalletSendRequest;
  public type WalletSendOut = Types.WalletSendOut;
  public type WalletSendResult = Types.WalletSendResult;
  public type WalletHistoryDirection = Types.WalletHistoryDirection;
  public type WalletHistoryItem = Types.WalletHistoryItem;
  public type WalletAssetHistoryResult = Types.WalletAssetHistoryResult;
  public type WalletIcrc1TokenAddResult = Types.WalletIcrc1TokenAddResult;
  public type WalletEvmTokenAddResult = Types.WalletEvmTokenAddResult;
  public type Deps = Types.Deps;

  public func networks(deps : Deps, caller : Principal) : [WalletNetworkInfo] {
    Networks.networks(deps, caller)
  };

  public func overview(
    deps : Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    erc20TokenAddress : ?Text,
  ) : async WalletOverviewResult {
    await Overview.overview(deps, caller, network, rpcUrl, erc20TokenAddress)
  };

  public func assetDetail(
    deps : Deps,
    caller : Principal,
    network : Text,
    symbol : Text,
    rpcUrl : ?Text,
    erc20TokenAddress : ?Text,
  ) : async WalletAssetDetailResult {
    await Overview.assetDetail(deps, caller, network, symbol, rpcUrl, erc20TokenAddress)
  };

  public func send(
    deps : Deps,
    caller : Principal,
    req : WalletSendRequest,
  ) : async WalletSendResult {
    await Send.send(deps, caller, req)
  };

  public func assetHistory(
    deps : Deps,
    caller : Principal,
    network : Text,
    symbol : Text,
    limit : Nat,
  ) : async WalletAssetHistoryResult {
    await History.assetHistory(deps, caller, network, symbol, limit)
  };
}
