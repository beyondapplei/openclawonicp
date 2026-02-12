import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

module {
  public type SendResult = Result.Result<Nat, Text>;
  public type BalanceResult = Result.Result<Nat, Text>;

  type Icrc1Account = { owner : Principal; subaccount : ?Blob };
  type Icrc1TransferArg = {
    from_subaccount : ?Blob;
    to : Icrc1Account;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
  };
  type Icrc1TransferError = {
    #BadFee : { expected_fee : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #InsufficientFunds : { balance : Nat };
    #TooOld;
    #CreatedInFuture : { ledger_time : Nat64 };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : Nat };
    #GenericError : { error_code : Nat; message : Text };
  };
  type Icrc1TransferResult = {
    #Ok : Nat;
    #Err : Icrc1TransferError;
  };

  type Icrc1BalanceOfArg = Icrc1Account;

  public func send(
    ledgerPrincipal : Principal,
    toPrincipalText : Text,
    amount : Nat,
    fee : ?Nat,
    memo : ?Blob,
    createdAtTime : ?Nat64,
  ) : async SendResult {
    if (amount == 0) return #err("amount must be > 0");

    let toPrincipal : Principal = try {
      Principal.fromText(Text.trim(toPrincipalText, #char ' '))
    } catch (_) {
      return #err("invalid destination principal")
    };

    let ledger : actor {
      icrc1_transfer : shared Icrc1TransferArg -> async Icrc1TransferResult;
    } = actor (Principal.toText(ledgerPrincipal));

    let arg : Icrc1TransferArg = {
      from_subaccount = null;
      to = { owner = toPrincipal; subaccount = null };
      fee;
      memo;
      created_at_time = createdAtTime;
      amount;
    };

    switch (await ledger.icrc1_transfer(arg)) {
      case (#Ok(blockIndex)) #ok(blockIndex);
      case (#Err(e)) #err(transferErrorText(e));
    }
  };

  public func balance(ledgerPrincipal : Principal, owner : Principal) : async BalanceResult {
    let ledger : actor {
      icrc1_balance_of : shared Icrc1BalanceOfArg -> async Nat;
    } = actor (Principal.toText(ledgerPrincipal));

    let arg : Icrc1BalanceOfArg = {
      owner;
      subaccount = null;
    };

    try {
      #ok(await ledger.icrc1_balance_of(arg))
    } catch (_) {
      #err("icrc1_balance_of failed")
    }
  };

  func transferErrorText(e : Icrc1TransferError) : Text {
    switch (e) {
      case (#BadFee(v)) "bad fee, expected " # Nat.toText(v.expected_fee);
      case (#BadBurn(v)) "bad burn, min " # Nat.toText(v.min_burn_amount);
      case (#InsufficientFunds(v)) "insufficient funds, balance " # Nat.toText(v.balance);
      case (#TooOld) "transfer too old";
      case (#CreatedInFuture(v)) "created in future, ledger_time " # Nat64.toText(v.ledger_time);
      case (#TemporarilyUnavailable) "ledger temporarily unavailable";
      case (#Duplicate(v)) "duplicate transfer at block " # Nat.toText(v.duplicate_of);
      case (#GenericError(v)) "ledger error " # Nat.toText(v.error_code) # ": " # v.message;
    }
  };
}
