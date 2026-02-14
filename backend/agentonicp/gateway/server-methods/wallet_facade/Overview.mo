import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import WalletEvm "../../../wallet/WalletEvm";
import WalletIcp "../../../wallet/WalletIcp";
import Types "./Types";
import Utils "./Utils";

module {
  public func overview(
    deps : Types.Deps,
    caller : Principal,
    network : Text,
    rpcUrl : ?Text,
    erc20TokenAddress : ?Text,
  ) : async Types.WalletOverviewResult {
    deps.assertOwner(caller);
    let canisterPrincipal = deps.selfPrincipal();
    let canisterPrincipalText = Principal.toText(canisterPrincipal);
    let selectedNetwork = Utils.normalizeWalletNetwork(network);
    let balances = Buffer.Buffer<Types.WalletBalanceItem>(4);
    let evmAddressOpt = if (selectedNetwork == "internet_computer" or selectedNetwork == "solana") {
      null
    } else {
      await resolveEvmAddress(deps, canisterPrincipal)
    };

    var primarySymbol : Text = "ICP";
    var primaryAmount : Nat = 0;
    var primaryAvailable : Bool = false;

    if (selectedNetwork == "internet_computer") {
      switch (
        await WalletIcp.balanceIcp(
          deps.icpLedgerLocalPrincipal,
          deps.icpLedgerMainnetPrincipal,
          canisterPrincipal,
        )
      ) {
        case (#ok(amount)) {
          primarySymbol := "ICP";
          primaryAmount := amount;
          primaryAvailable := true;
          balances.add({
            symbol = "ICP";
            name = "Internet Computer";
            network = selectedNetwork;
            decimals = 8;
            amount;
            available = true;
            address = canisterPrincipalText;
            error = null;
            tokenAddress = null;
            ledgerPrincipalText = null;
          });
        };
        case (#err(e)) {
          primarySymbol := "ICP";
          primaryAmount := 0;
          primaryAvailable := false;
          balances.add({
            symbol = "ICP";
            name = "Internet Computer";
            network = selectedNetwork;
            decimals = 8;
            amount = 0;
            available = false;
            address = canisterPrincipalText;
            error = ?e;
            tokenAddress = null;
            ledgerPrincipalText = null;
          });
        };
      };
      for (token in deps.icrc1Tokens.vals()) {
        let ledgerPrincipalText = Utils.trimText(token.ledgerPrincipalText);
        if (Text.size(ledgerPrincipalText) == 0) {
          balances.add({
            symbol = token.symbol;
            name = token.name;
            network = selectedNetwork;
            decimals = token.decimals;
            amount = 0;
            available = false;
            address = canisterPrincipalText;
            error = ?"missing ledger principal";
            tokenAddress = null;
            ledgerPrincipalText = null;
          });
        } else {
          switch (await WalletIcp.balanceIcrc1(ledgerPrincipalText, canisterPrincipal)) {
            case (#ok(amount)) {
              balances.add({
                symbol = token.symbol;
                name = token.name;
                network = selectedNetwork;
                decimals = token.decimals;
                amount;
                available = true;
                address = canisterPrincipalText;
                error = null;
                tokenAddress = null;
                ledgerPrincipalText = ?ledgerPrincipalText;
              });
            };
            case (#err(e)) {
              balances.add({
                symbol = token.symbol;
                name = token.name;
                network = selectedNetwork;
                decimals = token.decimals;
                amount = 0;
                available = false;
                address = canisterPrincipalText;
                error = ?e;
                tokenAddress = null;
                ledgerPrincipalText = ?ledgerPrincipalText;
              });
            };
          };
        };
      };
    } else if (selectedNetwork == "solana") {
      primarySymbol := "SOL";
      primaryAmount := 0;
      primaryAvailable := false;
      balances.add({
        symbol = "SOL";
        name = "Solana";
        network = selectedNetwork;
        decimals = 9;
        amount = 0;
        available = false;
        address = "";
        error = ?"solana wallet module not implemented";
        tokenAddress = null;
        ledgerPrincipalText = null;
      });
    } else if (Utils.isEvmNetwork(selectedNetwork)) {
      let addressText = switch (evmAddressOpt) {
        case null "";
        case (?addr) addr;
      };
      switch (
        await WalletEvm.balanceEth(
          deps.ic,
          deps.httpTransform,
          deps.defaultHttpCycles,
          deps.ic00,
          canisterPrincipal,
          canisterPrincipal,
          selectedNetwork,
          deps.effectiveRpcUrl(selectedNetwork, rpcUrl),
        )
      ) {
        case (#ok(amount)) {
          primarySymbol := "ETH";
          primaryAmount := amount;
          primaryAvailable := true;
          balances.add({
            symbol = "ETH";
            name = "Ethereum";
            network = selectedNetwork;
            decimals = 18;
            amount;
            available = true;
            address = addressText;
            error = null;
            tokenAddress = null;
            ledgerPrincipalText = null;
          });
        };
        case (#err(e)) {
          primarySymbol := "ETH";
          primaryAmount := 0;
          primaryAvailable := false;
          balances.add({
            symbol = "ETH";
            name = "Ethereum";
            network = selectedNetwork;
            decimals = 18;
            amount = 0;
            available = false;
            address = addressText;
            error = ?e;
            tokenAddress = null;
            ledgerPrincipalText = null;
          });
        };
      };
      let tokenCandidates = Buffer.Buffer<Types.WalletEvmToken>(8);
      let seen = Buffer.Buffer<Text>(8);
      for (token in deps.evmTokens.vals()) {
        if (Utils.normalizeWalletNetwork(token.network) == selectedNetwork) {
          let addr = Text.toLowercase(Utils.trimText(token.tokenAddress));
          if (Text.size(addr) > 0) {
            var exists = false;
            for (s in seen.vals()) {
              if (s == addr) {
                exists := true;
              };
            };
            if (not exists) {
              seen.add(addr);
              tokenCandidates.add(token);
            };
          };
        };
      };
      switch (Utils.trimOptText(erc20TokenAddress)) {
        case null {};
        case (?tokenAddress) {
          let addr = Text.toLowercase(tokenAddress);
          var exists = false;
          for (s in seen.vals()) {
            if (s == addr) {
              exists := true;
            };
          };
          if (not exists) {
            seen.add(addr);
            tokenCandidates.add({
              network = selectedNetwork;
              symbol = "ERC20";
              name = "ERC20 Token";
              tokenAddress;
              decimals = 18;
            });
          };
        };
      };

      for (token in tokenCandidates.vals()) {
        let tokenAddress = Utils.trimText(token.tokenAddress);
        if (Text.size(tokenAddress) > 0) {
          let rawSymbol = Utils.normalizeSymbol(token.symbol);
          let tokenSymbol = if (Text.size(rawSymbol) == 0) "ERC20" else rawSymbol;
          let rawName = Utils.trimText(token.name);
          let tokenName = if (Text.size(rawName) == 0) "ERC20 Token" else rawName;
          let tokenDecimals = if (token.decimals > 36) 18 else token.decimals;
          switch (
            await WalletEvm.balanceErc20(
              deps.ic,
              deps.httpTransform,
              deps.defaultHttpCycles,
              deps.ic00,
              canisterPrincipal,
              canisterPrincipal,
              selectedNetwork,
              deps.effectiveRpcUrl(selectedNetwork, rpcUrl),
              tokenAddress,
            )
          ) {
            case (#ok(amount)) {
              balances.add({
                symbol = tokenSymbol;
                name = tokenName;
                network = selectedNetwork;
                decimals = tokenDecimals;
                amount;
                available = true;
                address = addressText;
                error = null;
                tokenAddress = ?tokenAddress;
                ledgerPrincipalText = null;
              });
            };
            case (#err(e)) {
              balances.add({
                symbol = tokenSymbol;
                name = tokenName;
                network = selectedNetwork;
                decimals = tokenDecimals;
                amount = 0;
                available = false;
                address = addressText;
                error = ?e;
                tokenAddress = ?tokenAddress;
                ledgerPrincipalText = null;
              });
            };
          };
        };
      };
    } else {
      return #err("unsupported network: " # selectedNetwork);
    };

    #ok({
      canisterPrincipal;
      canisterPrincipalText;
      evmAddress = evmAddressOpt;
      selectedNetwork;
      primarySymbol;
      primaryAmount;
      primaryAvailable;
      balances = Buffer.toArray(balances);
      icpLedgerUseMainnet = deps.icpLedgerUseMainnet;
    })
  };

  public func assetDetail(
    deps : Types.Deps,
    caller : Principal,
    network : Text,
    symbol : Text,
    rpcUrl : ?Text,
    erc20TokenAddress : ?Text,
  ) : async Types.WalletAssetDetailResult {
    deps.assertOwner(caller);
    let wantedSymbol = Utils.normalizeSymbol(symbol);
    switch (await overview(deps, caller, network, rpcUrl, erc20TokenAddress)) {
      case (#err(e)) #err(e);
      case (#ok(out)) {
        var found : ?Types.WalletBalanceItem = null;
        label findItem for (item in out.balances.vals()) {
          if (Utils.normalizeSymbol(item.symbol) == wantedSymbol) {
            found := ?item;
            break findItem;
          };
        };
        switch (found) {
          case null #err("asset not found: " # wantedSymbol);
          case (?item) {
            #ok({
              symbol = item.symbol;
              name = item.name;
              network = item.network;
              decimals = item.decimals;
              amount = item.amount;
              available = item.available;
              address = item.address;
              error = item.error;
              receiveAddresses = Utils.resolveReceiveAddresses(out.selectedNetwork, item.symbol, item.address, out.canisterPrincipalText);
              tokenAddress = item.tokenAddress;
              ledgerPrincipalText = item.ledgerPrincipalText;
            })
          };
        }
      };
    }
  };

  func resolveEvmAddress(
    deps : Types.Deps,
    canisterPrincipal : Principal,
  ) : async ?Text {
    switch (await WalletEvm.ethAddress(deps.ic00, canisterPrincipal, canisterPrincipal)) {
      case (#ok(address)) ?address;
      case (#err(_)) null;
    }
  };
}
