import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

module {
  public type EcdsaCurve = { #secp256k1 };
  public type EcdsaKeyId = { curve : EcdsaCurve; name : Text };
  public type EcdsaPublicKeyArgs = {
    canister_id : ?Principal;
    derivation_path : [Blob];
    key_id : EcdsaKeyId;
  };
  public type EcdsaPublicKeyResponse = {
    public_key : Blob;
    chain_code : Blob;
  };
  public type SignWithEcdsaArgs = {
    message_hash : Blob;
    derivation_path : [Blob];
    key_id : EcdsaKeyId;
  };
  public type SignWithEcdsaResponse = {
    signature : Blob;
  };

  public type Ic00 = actor {
    ecdsa_public_key : EcdsaPublicKeyArgs -> async EcdsaPublicKeyResponse;
    sign_with_ecdsa : SignWithEcdsaArgs -> async SignWithEcdsaResponse;
  };

  public type AgentWallet = {
    principal : Principal;
    principalText : Text;
    keyName : Text;
    derivationPathHex : [Text];
    publicKeyHex : Text;
    chainCodeHex : Text;
  };

  public type EcdsaPublicKeyOut = {
    principal : Principal;
    principalText : Text;
    keyName : Text;
    derivationPathHex : [Text];
    publicKeyHex : Text;
    chainCodeHex : Text;
  };

  public type SignWithEcdsaOut = {
    principal : Principal;
    principalText : Text;
    keyName : Text;
    derivationPathHex : [Text];
    messageHashHex : Text;
    signatureHex : Text;
  };

  public type WalletResult = Result.Result<AgentWallet, Text>;
  public type EcdsaPublicKeyResult = Result.Result<EcdsaPublicKeyOut, Text>;
  public type SignWithEcdsaResult = Result.Result<SignWithEcdsaOut, Text>;

  public func ecdsaPublicKey(
    ic00 : Ic00,
    caller : Principal,
    canisterId : Principal,
    _derivationPath : [Blob],
    keyName : ?Text,
  ) : async EcdsaPublicKeyResult {
    let path = defaultWalletPath();
    switch (await ecdsaPublicKeyWithFallback(ic00, canisterId, path, keyName)) {
      case (#err(e)) #err(e);
      case (#ok((usedKey, resp))) {
        #ok({
          principal = caller;
          principalText = Principal.toText(caller);
          keyName = usedKey;
          derivationPathHex = blobPathToHex(path);
          publicKeyHex = blobToHex(resp.public_key);
          chainCodeHex = blobToHex(resp.chain_code);
        })
      };
    }
  };

  public func signWithEcdsa(
    ic00 : Ic00,
    caller : Principal,
    messageHash : Blob,
    _derivationPath : [Blob],
    keyName : ?Text,
  ) : async SignWithEcdsaResult {
    if (Blob.toArray(messageHash).size() != 32) {
      return #err("message_hash must be 32 bytes");
    };

    let path = defaultWalletPath();
    switch (await signWithEcdsaWithFallback(ic00, messageHash, path, keyName)) {
      case (#err(e)) #err(e);
      case (#ok((usedKey, resp))) {
        #ok({
          principal = caller;
          principalText = Principal.toText(caller);
          keyName = usedKey;
          derivationPathHex = blobPathToHex(path);
          messageHashHex = blobToHex(messageHash);
          signatureHex = blobToHex(resp.signature);
        })
      };
    }
  };

  public func agentWallet(ic00 : Ic00, caller : Principal, canisterId : Principal) : async WalletResult {
    let path = defaultWalletPath();

    switch (await ecdsaPublicKeyWithFallback(ic00, canisterId, path, null)) {
      case (#err(e)) #err(e);
      case (#ok((keyName, resp))) {
        #ok({
          principal = caller;
          principalText = Principal.toText(caller);
          keyName;
          derivationPathHex = blobPathToHex(path);
          publicKeyHex = blobToHex(resp.public_key);
          chainCodeHex = blobToHex(resp.chain_code);
        })
      };
    }
  };

  func defaultWalletPath() : [Blob] {
    []
  };

  func preferredKeyOrDefault(keyName : ?Text) : Text {
    switch (keyName) {
      case null "key_1";
      case (?k) {
        let trimmed = Text.trim(k, #char ' ');
        if (Text.size(trimmed) == 0) "key_1" else trimmed
      };
    }
  };

  func fallbackKeyName(primary : Text) : Text {
    if (primary == "dfx_test_key") "key_1" else "dfx_test_key"
  };

  func ecdsaPublicKeyWithFallback(ic00 : Ic00, canisterId : Principal, path : [Blob], keyName : ?Text) : async Result.Result<(Text, EcdsaPublicKeyResponse), Text> {
    let primary = preferredKeyOrDefault(keyName);
    switch (await ecdsaPublicKeyWithKey(ic00, canisterId, path, primary)) {
      case (#ok(r)) #ok((primary, r));
      case (#err(_)) {
        let fb = fallbackKeyName(primary);
        switch (await ecdsaPublicKeyWithKey(ic00, canisterId, path, fb)) {
          case (#ok(r2)) #ok((fb, r2));
          case (#err(_)) #err("ecdsa_public_key failed for " # primary # " and " # fb);
        }
      };
    }
  };

  func ecdsaPublicKeyWithKey(ic00 : Ic00, canisterId : Principal, path : [Blob], keyName : Text) : async Result.Result<EcdsaPublicKeyResponse, Text> {
    let req : EcdsaPublicKeyArgs = {
      canister_id = ?canisterId;
      derivation_path = path;
      key_id = { curve = #secp256k1; name = keyName };
    };
    try {
      #ok(await ic00.ecdsa_public_key(req))
    } catch (_) {
      #err("ecdsa_public_key failed for key " # keyName)
    }
  };

  func signWithEcdsaWithFallback(ic00 : Ic00, messageHash : Blob, path : [Blob], keyName : ?Text) : async Result.Result<(Text, SignWithEcdsaResponse), Text> {
    let primary = preferredKeyOrDefault(keyName);
    switch (await signWithEcdsaWithKey(ic00, messageHash, path, primary)) {
      case (#ok(r)) #ok((primary, r));
      case (#err(_)) {
        let fb = fallbackKeyName(primary);
        switch (await signWithEcdsaWithKey(ic00, messageHash, path, fb)) {
          case (#ok(r2)) #ok((fb, r2));
          case (#err(_)) #err("sign_with_ecdsa failed for " # primary # " and " # fb);
        }
      };
    }
  };

  func signWithEcdsaWithKey(ic00 : Ic00, messageHash : Blob, path : [Blob], keyName : Text) : async Result.Result<SignWithEcdsaResponse, Text> {
    let req : SignWithEcdsaArgs = {
      message_hash = messageHash;
      derivation_path = path;
      key_id = { curve = #secp256k1; name = keyName };
    };
    try {
      #ok(await ic00.sign_with_ecdsa(req))
    } catch (_) {
      #err("sign_with_ecdsa failed for key " # keyName)
    }
  };

  func blobPathToHex(path : [Blob]) : [Text] {
    Array.map<Blob, Text>(path, func (b : Blob) : Text { blobToHex(b) })
  };

  func blobToHex(b : Blob) : Text {
    let table = [
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
    ];
    var out = "";
    for (byte in Blob.toArray(b).vals()) {
      let hi = Nat8.toNat(byte / 16);
      let lo = Nat8.toNat(byte % 16);
      out #= table[hi] # table[lo];
    };
    out
  };
}