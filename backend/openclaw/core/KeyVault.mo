import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Result "mo:base/Result";
import Text "mo:base/Text";

import Types "./Types";

module {
  public type EncMap = [(Text, Text)];

  public func setProviderApiKey(entries : EncMap, provider : Types.Provider, apiKey : Text) : EncMap {
    let key = Text.trim(apiKey, #char ' ');
    let providerKey = providerToKey(provider);
    if (Text.size(key) == 0) {
      mapDelete(entries, providerKey)
    } else {
      mapPut(entries, providerKey, encryptSecret(key))
    }
  };

  public func hasProviderApiKey(entries : EncMap, provider : Types.Provider) : Bool {
    switch (mapGet(entries, providerToKey(provider))) {
      case null false;
      case (?_) true;
    }
  };

  public func resolveApiKey(entries : EncMap, provider : Types.Provider, providedApiKey : Text) : Result.Result<Text, Text> {
    let provided = Text.trim(providedApiKey, #char ' ');
    if (Text.size(provided) > 0) return #ok(provided);

    switch (mapGet(entries, providerToKey(provider))) {
      case null #err("apiKey is required (set it in admin or pass per-call)");
      case (?enc) {
        switch (decryptSecret(enc)) {
          case null #err("stored apiKey decrypt failed");
          case (?key) {
            if (Text.size(Text.trim(key, #char ' ')) == 0) {
              #err("stored apiKey is empty")
            } else {
              #ok(key)
            }
          };
        }
      };
    }
  };

  func providerToKey(provider : Types.Provider) : Text {
    switch (provider) {
      case (#openai) "openai";
      case (#anthropic) "anthropic";
      case (#google) "google";
    }
  };

  func encryptSecret(plain : Text) : Text {
    bytesToHex(xorWithMask(Blob.toArray(Text.encodeUtf8(plain))))
  };

  func decryptSecret(encHex : Text) : ?Text {
    switch (hexToBytes(encHex)) {
      case null null;
      case (?bytes) Text.decodeUtf8(Blob.fromArray(xorWithMask(bytes)));
    }
  };

  func xorWithMask(bytes : [Nat8]) : [Nat8] {
    let mask = Blob.toArray(Text.encodeUtf8("openclaw-api-key-mask-v1"));
    if (mask.size() == 0) return bytes;
    let out = Buffer.Buffer<Nat8>(bytes.size());
    var i : Nat = 0;
    while (i < bytes.size()) {
      let m = mask[i % mask.size()];
      out.add(bytes[i] ^ m);
      i += 1;
    };
    Buffer.toArray(out)
  };

  func mapGet(entries : EncMap, key : Text) : ?Text {
    for ((k, v) in entries.vals()) {
      if (k == key) return ?v;
    };
    null
  };

  func mapPut(entries : EncMap, key : Text, value : Text) : EncMap {
    let out = Buffer.Buffer<(Text, Text)>(entries.size() + 1);
    var replaced = false;
    for ((k, v) in entries.vals()) {
      if (k == key) {
        out.add((k, value));
        replaced := true;
      } else {
        out.add((k, v));
      }
    };
    if (not replaced) out.add((key, value));
    Buffer.toArray(out)
  };

  func mapDelete(entries : EncMap, key : Text) : EncMap {
    let out = Buffer.Buffer<(Text, Text)>(entries.size());
    for ((k, v) in entries.vals()) {
      if (k != key) out.add((k, v));
    };
    Buffer.toArray(out)
  };

  func bytesToHex(bytes : [Nat8]) : Text {
    let table = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"];
    var out = "";
    for (byte in bytes.vals()) {
      let hi = Nat8.toNat(byte / 16);
      let lo = Nat8.toNat(byte % 16);
      out #= table[hi] # table[lo];
    };
    out
  };

  func hexDigit(c : Char) : ?Nat {
    let n = Char.toNat32(c);
    if (n >= 48 and n <= 57) return ?Nat32.toNat(n - 48);
    if (n >= 65 and n <= 70) return ?Nat32.toNat(n - 55);
    if (n >= 97 and n <= 102) return ?Nat32.toNat(n - 87);
    null
  };

  func hexToBytes(input : Text) : ?[Nat8] {
    let t = Text.trim(input, #char ' ');
    let chars = Buffer.Buffer<Char>(Text.size(t));
    for (c in t.chars()) chars.add(c);
    let n = chars.size();
    if (n == 0) return ?[];
    if (n % 2 != 0) return null;
    let out = Buffer.Buffer<Nat8>(n / 2);
    var i : Nat = 0;
    while (i < n) {
      let hi = switch (hexDigit(chars.get(i))) { case null return null; case (?v) v };
      let lo = switch (hexDigit(chars.get(i + 1))) { case null return null; case (?v) v };
      out.add(Nat8.fromNat(hi * 16 + lo));
      i += 2;
    };
    ?Buffer.toArray(out)
  };
}
