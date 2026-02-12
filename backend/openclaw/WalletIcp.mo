import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import TokenTransfer "./TokenTransfer";

module {
  public type SendIcpResult = Result.Result<Nat, Text>;
  public type SendIcrc1Result = Result.Result<Nat, Text>;
  public type BalanceResult = Result.Result<Nat, Text>;

  type Icrc1FeeProbe = actor {
    icrc1_fee : shared () -> async Nat;
  };

  func isLedgerReachable(ledgerPrincipal : Principal) : async Bool {
    let ledger : Icrc1FeeProbe = actor (Principal.toText(ledgerPrincipal));
    try {
      ignore await ledger.icrc1_fee();
      true
    } catch (_) {
      false
    }
  };

  func resolveIcpLedgerPrincipal(localLedgerPrincipal : Principal, mainnetLedgerPrincipal : Principal) : async Principal {
    if (await isLedgerReachable(localLedgerPrincipal)) {
      localLedgerPrincipal
    } else {
      mainnetLedgerPrincipal
    }
  };

  public func sendIcp(
    localLedgerPrincipal : Principal,
    mainnetLedgerPrincipal : Principal,
    toPrincipalText : Text,
    amountE8s : Nat64,
  ) : async SendIcpResult {
    let ledgerPrincipal = await resolveIcpLedgerPrincipal(localLedgerPrincipal, mainnetLedgerPrincipal);
    await TokenTransfer.send(ledgerPrincipal, toPrincipalText, Nat64.toNat(amountE8s), null, null, null)
  };

  public func sendIcrc1(
    ledgerPrincipalText : Text,
    toPrincipalText : Text,
    amount : Nat,
    fee : ?Nat,
  ) : async SendIcrc1Result {
    let ledgerPrincipal : Principal = try {
      Principal.fromText(Text.trim(ledgerPrincipalText, #char ' '))
    } catch (_) {
      return #err("invalid ledger principal")
    };
    await TokenTransfer.send(ledgerPrincipal, toPrincipalText, amount, fee, null, null)
  };

  public func balanceIcp(
    localLedgerPrincipal : Principal,
    mainnetLedgerPrincipal : Principal,
    ownerPrincipal : Principal,
  ) : async BalanceResult {
    let ledgerPrincipal = await resolveIcpLedgerPrincipal(localLedgerPrincipal, mainnetLedgerPrincipal);
    await TokenTransfer.balance(ledgerPrincipal, ownerPrincipal)
  };

  public func balanceIcrc1(ledgerPrincipalText : Text, ownerPrincipal : Principal) : async BalanceResult {
    let ledgerPrincipal : Principal = try {
      Principal.fromText(Text.trim(ledgerPrincipalText, #char ' '))
    } catch (_) {
      return #err("invalid ledger principal")
    };
    await TokenTransfer.balance(ledgerPrincipal, ownerPrincipal)
  };
}
