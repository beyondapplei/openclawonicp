import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import AppConfig "../core/AppConfig";

module {
  let ecdsaCallCycles = 30_000_000_000;

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
    derivationPath : [Blob],
    keyName : ?Text,
  ) : async EcdsaPublicKeyResult {
    let path = effectiveDerivationPath(canisterId, derivationPath);
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
    canisterId : Principal,
    messageHash : Blob,
    derivationPath : [Blob],
    keyName : ?Text,
  ) : async SignWithEcdsaResult {
    if (Blob.toArray(messageHash).size() != 32) {
      return #err("message_hash must be 32 bytes");
    };

    let path = effectiveDerivationPath(canisterId, derivationPath);
    switch (await signWithEcdsaWithFallback(ic00, path, messageHash, keyName)) {
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
    let path = defaultWalletPath(canisterId);

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

  func defaultWalletPath(canisterId : Principal) : [Blob] {
    [Principal.toBlob(canisterId), Text.encodeUtf8("agentonicp")]
  };

  func effectiveDerivationPath(canisterId : Principal, requestPath : [Blob]) : [Blob] {
    if (requestPath.size() > 0) {
      requestPath
    } else {
      defaultWalletPath(canisterId)
    }
  };

  func ecdsaPublicKeyWithFallback(ic00 : Ic00, canisterId : Principal, derivationPath : [Blob], keyName : ?Text) : async Result.Result<(Text, EcdsaPublicKeyResponse), Text> {
    let candidates = candidateKeyNames(keyName);
    let errs = Buffer.Buffer<Text>(candidates.size());
    for (k in candidates.vals()) {
      switch (await ecdsaPublicKeyWithKey(ic00, canisterId, derivationPath, k)) {
        case (#ok(r)) return #ok((k, r));
        case (#err(e)) errs.add(e);
      };
    };
    #err("ecdsa_public_key failed for all keys: " # joinErrors(errs))
  };

  func candidateKeyNames(keyName : ?Text) : [Text] {
    let preferred = switch (keyName) {
      case null AppConfig.defaultEcdsaKeyName();
      case (?k) {
        let trimmed = Text.trim(k, #char ' ');
        if (Text.size(trimmed) == 0) AppConfig.defaultEcdsaKeyName() else trimmed
      };
    };
    let defaults : [Text] = AppConfig.ecdsaFallbackKeyNames();
    let out = Buffer.Buffer<Text>(defaults.size() + 1);
    out.add(preferred);
    for (k in defaults.vals()) {
      var exists = false;
      for (existing in out.vals()) {
        if (existing == k) {
          exists := true;
        };
      };
      if (not exists) {
        out.add(k);
      };
    };
    Buffer.toArray(out)
  };

  func joinErrors(errs : Buffer.Buffer<Text>) : Text {
    var out = "";
    var first = true;
    for (e in errs.vals()) {
      if (first) {
        out := e;
        first := false;
      } else {
        out #= " | " # e;
      };
    };
    out
  };

  func ecdsaPublicKeyWithKey(ic00 : Ic00, canisterId : Principal, derivationPath : [Blob], keyName : Text) : async Result.Result<EcdsaPublicKeyResponse, Text> {
    let req : EcdsaPublicKeyArgs = {
      canister_id = ?canisterId;
      derivation_path = derivationPath;
      key_id = { curve = #secp256k1; name = keyName };
    };
    try {
      #ok(await (with cycles = ecdsaCallCycles) ic00.ecdsa_public_key(req))
    } catch (e) {
      #err("ecdsa_public_key failed for key " # keyName # ": " # Error.message(e))
    }
  };

  func signWithEcdsaWithFallback(ic00 : Ic00, derivationPath : [Blob], messageHash : Blob, keyName : ?Text) : async Result.Result<(Text, SignWithEcdsaResponse), Text> {
    let candidates = candidateKeyNames(keyName);
    let errs = Buffer.Buffer<Text>(candidates.size());
    for (k in candidates.vals()) {
      switch (await signWithEcdsaWithKey(ic00, derivationPath, messageHash, k)) {
        case (#ok(r)) return #ok((k, r));
        case (#err(e)) errs.add(e);
      };
    };
    #err("sign_with_ecdsa failed for all keys: " # joinErrors(errs))
  };

  func signWithEcdsaWithKey(ic00 : Ic00, derivationPath : [Blob], messageHash : Blob, keyName : Text) : async Result.Result<SignWithEcdsaResponse, Text> {
    let req : SignWithEcdsaArgs = {
      message_hash = messageHash;
      derivation_path = derivationPath;
      key_id = { curve = #secp256k1; name = keyName };
    };
    try {
      #ok(await (with cycles = ecdsaCallCycles) ic00.sign_with_ecdsa(req))
    } catch (e) {
      #err("sign_with_ecdsa failed for key " # keyName # ": " # Error.message(e))
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
