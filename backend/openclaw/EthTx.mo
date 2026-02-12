import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Text "mo:base/Text";
import SHA3 "mo:sha3";

import HttpTypes "./HttpTypes";
import Json "./Json";
import Wallet "./Wallet";
import Llm "./Llm";

module {
  public type SendEthResult = Result.Result<Text, Text>;
  public type BalanceResult = Result.Result<Nat, Text>;
  public type AddressResult = Result.Result<Text, Text>;

  public func ethAddress(
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
  ) : async AddressResult {
    await backendEthAddress(ic00, caller, canisterId)
  };

  public func sendRaw(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    network : Text,
    rpcUrl : ?Text,
    rawTxHex : Text,
  ) : async SendEthResult {
    let raw = Text.trim(rawTxHex, #char ' ');
    if (Text.size(raw) < 4 or not Text.startsWith(raw, #text "0x")) {
      return #err("rawTxHex must start with 0x");
    };

    let url = switch (resolveRpcUrl(network, rpcUrl)) {
      case (#ok(u)) u;
      case (#err(e)) return #err(e);
    };

    let bodyText = "{" #
      "\"jsonrpc\":\"2.0\"," #
      "\"id\":1," #
      "\"method\":\"eth_sendRawTransaction\"," #
      "\"params\":[\"" # Json.escape(raw) # "\"]" #
      "}";

    let req : HttpTypes.HttpRequestArgs = {
      url;
      max_response_bytes = ?(1_000_000 : Nat64);
      method = #post;
      headers = [{ name = "Content-Type"; value = "application/json" }];
      body = ?Text.encodeUtf8(bodyText);
      transform = ?{
        function = transform;
        context = Blob.fromArray([]);
      };
    };

    let resp = await (with cycles = httpCycles) ic.http_request(req);
    let payload = switch (Text.decodeUtf8(resp.body)) {
      case null "";
      case (?t) t;
    };

    if (resp.status < 200 or resp.status >= 300) {
      return #err("rpc http status " # Nat.toText(resp.status) # ": " # payload);
    };

    switch (Json.extractStringAfterAny(payload, ["\"result\":\"", "\"result\": \""])) {
      case (?txHash) #ok(txHash);
      case null {
        switch (Json.extractStringAfterAny(payload, ["\"message\":\"", "\"message\": \""])) {
          case (?msg) #err("rpc error: " # msg);
          case null #err("rpc error: " # payload);
        }
      }
    }
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
    if (amountWei == 0) return #err("amount must be > 0");
    await sendTransaction(ic, transform, httpCycles, ic00, caller, canisterId, network, rpcUrl, toAddress, amountWei, [])
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
    if (amount == 0) return #err("amount must be > 0");
    if (natToBytes(amount).size() > 32) return #err("erc20 amount exceeds uint256");

    let tokenBytes = switch (parseAddress20(tokenAddress)) {
      case null return #err("invalid erc20 token address");
      case (?b) b;
    };
    let toBytes = switch (parseAddress20(toAddress)) {
      case null return #err("invalid erc20 destination address");
      case (?b) b;
    };

    let data = encodeErc20TransferData(toBytes, amount);
    await sendTransaction(
      ic,
      transform,
      httpCycles,
      ic00,
      caller,
      canisterId,
      network,
      rpcUrl,
      "0x" # bytesToHex(tokenBytes),
      0,
      data,
    )
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
    let url = switch (resolveRpcUrl(network, rpcUrl)) {
      case (#ok(u)) u;
      case (#err(e)) return #err(e);
    };
    let signerAddress = switch (await backendEthAddress(ic00, caller, canisterId)) {
      case (#ok(a)) a;
      case (#err(e)) return #err(e);
    };
    await rpcHexNat(ic, transform, httpCycles, url, "eth_getBalance", "[\"" # Json.escape(signerAddress) # "\",\"latest\"]")
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
    let url = switch (resolveRpcUrl(network, rpcUrl)) {
      case (#ok(u)) u;
      case (#err(e)) return #err(e);
    };
    let tokenBytes = switch (parseAddress20(tokenAddress)) {
      case null return #err("invalid erc20 token address");
      case (?b) b;
    };
    let signerAddress = switch (await backendEthAddress(ic00, caller, canisterId)) {
      case (#ok(a)) a;
      case (#err(e)) return #err(e);
    };
    let signerBytes = switch (parseAddress20(signerAddress)) {
      case null return #err("invalid signer address");
      case (?b) b;
    };

    let payload = switch (
      await rpcCall(
        ic,
        transform,
        httpCycles,
        url,
        "eth_call",
        "[{\"to\":\"0x" # bytesToHex(tokenBytes) # "\",\"data\":\"0x" # bytesToHex(encodeErc20BalanceOfData(signerBytes)) # "\"},\"latest\"]",
      )
    ) {
      case (#ok(p)) p;
      case (#err(e)) return #err(e);
    };

    switch (Json.extractStringAfterAny(payload, ["\"result\":\"", "\"result\": \""])) {
      case null #err("erc20 balance result missing");
      case (?hex) {
        switch (hexToNat(hex)) {
          case null #err("invalid erc20 balance result");
          case (?n) #ok(n);
        }
      }
    }
  };

  func sendTransaction(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    ic00 : Wallet.Ic00,
    caller : Principal,
    canisterId : Principal,
    network : Text,
    rpcUrl : ?Text,
    toAddress : Text,
    valueWei : Nat,
    data : [Nat8],
  ) : async SendEthResult {
    let url = switch (resolveRpcUrl(network, rpcUrl)) {
      case (#ok(u)) u;
      case (#err(e)) return #err(e);
    };

    let signerAddress = switch (await backendEthAddress(ic00, caller, canisterId)) {
      case (#ok(a)) a;
      case (#err(e)) return #err(e);
    };

    let nonce = switch (await rpcHexNat(ic, transform, httpCycles, url, "eth_getTransactionCount", "[\"" # Json.escape(signerAddress) # "\",\"pending\"]")) {
      case (#ok(n)) n;
      case (#err(e)) return #err(e);
    };

    let gasPrice = switch (await rpcHexNat(ic, transform, httpCycles, url, "eth_gasPrice", "[]")) {
      case (#ok(g)) g;
      case (#err(e)) return #err(e);
    };

    let toBytes = switch (parseAddress20(toAddress)) {
      case null return #err("invalid eth address");
      case (?b) b;
    };

    let valueField = if (valueWei > 0) ",\"value\":\"" # natToHex(valueWei) # "\"" else "";
    let dataField = if (data.size() > 0) ",\"data\":\"0x" # bytesToHex(data) # "\"" else "";
    let estimateParams = "[{\"from\":\"" # Json.escape(signerAddress) # "\",\"to\":\"0x" # bytesToHex(toBytes) # "\"" # valueField # dataField # "}]";

    let gasEstimate = switch (await rpcHexNat(ic, transform, httpCycles, url, "eth_estimateGas", estimateParams)) {
      case (#ok(g)) g;
      case (#err(e)) return #err(e);
    };

    let gas = (gasEstimate * 12) / 10;
    let maxPriorityFeePerGas = if (gasPrice / 10 == 0) 1 else gasPrice / 10;
    let chainId : Nat = if (isBase(network)) 8453 else 1;

    let unsigned = encodeEip1559Unsigned(chainId, nonce, maxPriorityFeePerGas, gasPrice, gas, toBytes, valueWei, data);
    let txHash = keccak256(unsigned);

    let signRes = await Wallet.signWithEcdsa(ic00, caller, Blob.fromArray(txHash), [], null);
    let sigHex = switch (signRes) {
      case (#ok(ok)) ok.signatureHex;
      case (#err(e)) return #err(e);
    };

    let sigBytes = switch (hexToBytes(sigHex)) {
      case null return #err("invalid signature hex from sign_with_ecdsa");
      case (?s) {
        if (s.size() != 64) return #err("invalid signature length");
        s
      };
    };

    let rNat = bytesToNat(slice(sigBytes, 0, 32));
    let s0 = bytesToNat(slice(sigBytes, 32, 64));
    let n = secp256k1N();
    var s = s0;
    if (s > n) {
      s := s % n;
    };
    if (s > n / 2) {
      s := n - s;
    };

    let raw0 = "0x" # bytesToHex(encodeEip1559Signed(chainId, nonce, maxPriorityFeePerGas, gasPrice, gas, toBytes, valueWei, data, 0, rNat, s));
    switch (await sendRaw(ic, transform, httpCycles, network, rpcUrl, raw0)) {
      case (#ok(txh)) return #ok(txh);
      case (#err(_)) {};
    };

    let raw1 = "0x" # bytesToHex(encodeEip1559Signed(chainId, nonce, maxPriorityFeePerGas, gasPrice, gas, toBytes, valueWei, data, 1, rNat, s));
    switch (await sendRaw(ic, transform, httpCycles, network, rpcUrl, raw1)) {
      case (#ok(txh1)) #ok(txh1);
      case (#err(e1)) #err("both yParity attempts failed: " # e1);
    }
  };

  func parseAddress20(input : Text) : ?[Nat8] {
    switch (hexToBytes(Text.trim(input, #char ' '))) {
      case null null;
      case (?b) {
        if (b.size() != 20) return null;
        ?b
      };
    }
  };

  func encodeErc20TransferData(to : [Nat8], amount : Nat) : [Nat8] {
    concatAll([
      [0xa9, 0x05, 0x9c, 0xbb],
      leftPad32(to),
      natToFixed32(amount),
    ])
  };

  func encodeErc20BalanceOfData(owner : [Nat8]) : [Nat8] {
    Array.append<Nat8>([0x70, 0xa0, 0x82, 0x31], leftPad32(owner))
  };

  func leftPad32(bytes : [Nat8]) : [Nat8] {
    if (bytes.size() >= 32) return bytes;
    let out = Buffer.Buffer<Nat8>(32);
    var i : Nat = 0;
    let padLen = natSubOrZero(32, bytes.size());
    while (i < padLen) {
      out.add(0);
      i += 1;
    };
    for (b in bytes.vals()) out.add(b);
    Buffer.toArray(out)
  };

  func natToFixed32(n : Nat) : [Nat8] {
    let raw = natToBytes(n);
    if (raw.size() > 32) {
      slice(raw, raw.size() - 32, raw.size())
    } else {
      leftPad32(raw)
    }
  };

  func natSubOrZero(a : Nat, b : Nat) : Nat {
    if (a > b) {
      a - b
    } else {
      0
    }
  };

  func backendEthAddress(ic00 : Wallet.Ic00, caller : Principal, canisterId : Principal) : async Result.Result<Text, Text> {
    switch (await Wallet.agentWallet(ic00, caller, canisterId)) {
      case (#err(e)) #err(e);
      case (#ok(w)) {
        switch (hexToBytes(w.publicKeyHex)) {
          case null #err("invalid public key hex");
          case (?pub) {
            let uncompressedNoPrefix = switch (secp256k1UncompressedNoPrefix(pub)) {
              case (#ok(v)) v;
              case (#err(e2)) return #err(e2);
            };
            let hash = keccak256(uncompressedNoPrefix);
            let addr = slice(hash, 12, 32);
            #ok("0x" # bytesToHex(addr));
          };
        }
      };
    }
  };

  func secp256k1UncompressedNoPrefix(pub : [Nat8]) : Result.Result<[Nat8], Text> {
    if (pub.size() == 65) {
      if (pub[0] != 0x04) return #err("unexpected uncompressed public key format");
      return #ok(slice(pub, 1, 65));
    };

    if (pub.size() == 33) {
      let prefix = pub[0];
      if (prefix != 0x02 and prefix != 0x03) return #err("unexpected compressed public key format");
      let xBytes = slice(pub, 1, 33);
      let x = bytesToNat(xBytes);
      let p = secp256k1P();
      if (x >= p) return #err("invalid compressed public key x");

      let ySquared = (modMul(modMul(x, x, p), x, p) + 7) % p;
      let yRoot = modExp(ySquared, (p + 1) / 4, p);
      if (modMul(yRoot, yRoot, p) != ySquared) return #err("invalid compressed public key point");

      let wantOdd = (prefix == 0x03);
      let rootOdd = (yRoot % 2 == 1);
      let y = if (rootOdd == wantOdd) {
        yRoot
      } else {
        if (yRoot <= p) {
          (p - yRoot) % p
        } else {
          return #err("invalid compressed public key root");
        }
      };

      return #ok(Array.append<Nat8>(natToFixed32(x), natToFixed32(y)));
    };

    #err("unexpected public key length")
  };

  func modMul(a : Nat, b : Nat, m : Nat) : Nat {
    (a * b) % m
  };

  func modExp(base : Nat, exp : Nat, m : Nat) : Nat {
    if (m == 1) return 0;
    var result : Nat = 1;
    var b = base % m;
    var e = exp;
    while (e > 0) {
      if (e % 2 == 1) {
        result := modMul(result, b, m);
      };
      b := modMul(b, b, m);
      e /= 2;
    };
    result
  };

  func keccak256(bytes : [Nat8]) : [Nat8] {
    let k = SHA3.Keccak(256);
    k.update(bytes);
    k.finalize()
  };

  func encodeEip1559Unsigned(
    chainId : Nat,
    nonce : Nat,
    maxPriorityFeePerGas : Nat,
    maxFeePerGas : Nat,
    gasLimit : Nat,
    to : [Nat8],
    value : Nat,
    data : [Nat8],
  ) : [Nat8] {
    let payload = rlpEncodeList([
      rlpEncodeNat(chainId),
      rlpEncodeNat(nonce),
      rlpEncodeNat(maxPriorityFeePerGas),
      rlpEncodeNat(maxFeePerGas),
      rlpEncodeNat(gasLimit),
      rlpEncodeBytes(to),
      rlpEncodeNat(value),
      rlpEncodeBytes(data),
      rlpEncodeList([]),
    ]);
    Array.append<Nat8>([0x02], payload)
  };

  func encodeEip1559Signed(
    chainId : Nat,
    nonce : Nat,
    maxPriorityFeePerGas : Nat,
    maxFeePerGas : Nat,
    gasLimit : Nat,
    to : [Nat8],
    value : Nat,
    data : [Nat8],
    yParity : Nat,
    r : Nat,
    s : Nat,
  ) : [Nat8] {
    let payload = rlpEncodeList([
      rlpEncodeNat(chainId),
      rlpEncodeNat(nonce),
      rlpEncodeNat(maxPriorityFeePerGas),
      rlpEncodeNat(maxFeePerGas),
      rlpEncodeNat(gasLimit),
      rlpEncodeBytes(to),
      rlpEncodeNat(value),
      rlpEncodeBytes(data),
      rlpEncodeList([]),
      rlpEncodeNat(yParity),
      rlpEncodeNat(r),
      rlpEncodeNat(s),
    ]);
    Array.append<Nat8>([0x02], payload)
  };

  func rlpEncodeNat(n : Nat) : [Nat8] {
    rlpEncodeBytes(natToBytes(n))
  };

  func rlpEncodeBytes(bytes : [Nat8]) : [Nat8] {
    let len = bytes.size();
    if (len == 1 and bytes[0] < 0x80) return bytes;
    if (len <= 55) {
      return Array.append<Nat8>([Nat8.fromNat(0x80 + len)], bytes);
    };
    let lenBytes = natToBytes(len);
    Array.append<Nat8>(Array.append<Nat8>([Nat8.fromNat(0xb7 + lenBytes.size())], lenBytes), bytes)
  };

  func rlpEncodeList(items : [[Nat8]]) : [Nat8] {
    let payload = concatAll(items);
    let len = payload.size();
    if (len <= 55) {
      return Array.append<Nat8>([Nat8.fromNat(0xc0 + len)], payload);
    };
    let lenBytes = natToBytes(len);
    Array.append<Nat8>(Array.append<Nat8>([Nat8.fromNat(0xf7 + lenBytes.size())], lenBytes), payload)
  };

  func concatAll(chunks : [[Nat8]]) : [Nat8] {
    let b = Buffer.Buffer<Nat8>(0);
    for (c in chunks.vals()) {
      for (x in c.vals()) b.add(x);
    };
    Buffer.toArray(b)
  };

  func natToBytes(n : Nat) : [Nat8] {
    if (n == 0) return [];
    var x = n;
    let b = Buffer.Buffer<Nat8>(0);
    while (x > 0) {
      b.add(Nat8.fromNat(x % 256));
      x /= 256;
    };
    let little = Buffer.toArray(b);
    let out = Buffer.Buffer<Nat8>(little.size());
    var i : Nat = little.size();
    while (i > 0) {
      i -= 1;
      out.add(little[i]);
    };
    Buffer.toArray(out)
  };

  func slice(bytes : [Nat8], from : Nat, to : Nat) : [Nat8] {
    let out = Buffer.Buffer<Nat8>(to - from);
    var i = from;
    while (i < to) {
      out.add(bytes[i]);
      i += 1;
    };
    Buffer.toArray(out)
  };

  func bytesToNat(bytes : [Nat8]) : Nat {
    var n : Nat = 0;
    for (b in bytes.vals()) {
      n := n * 256 + Nat8.toNat(b);
    };
    n
  };

  func bytesToHex(bytes : [Nat8]) : Text {
    let table = [
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
    ];
    var out = "";
    for (byte in bytes.vals()) {
      let hi = Nat8.toNat(byte / 16);
      let lo = Nat8.toNat(byte % 16);
      out #= table[hi] # table[lo];
    };
    out
  };

  func hexToBytes(input : Text) : ?[Nat8] {
    let t = Text.trim(input, #char ' ');
    let raw = switch (Text.stripStart(t, #text "0x")) {
      case (?v) v;
      case null switch (Text.stripStart(t, #text "0X")) {
        case (?v2) v2;
        case null t;
      };
    };
    let chars = Buffer.Buffer<Char>(Text.size(raw));
    for (c in raw.chars()) chars.add(c);
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

  func secp256k1N() : Nat {
    switch (hexToNat("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")) {
      case (?n) n;
      case null Debug.trap("invalid secp256k1 curve order");
    }
  };

  func secp256k1P() : Nat {
    switch (hexToNat("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F")) {
      case (?p) p;
      case null Debug.trap("invalid secp256k1 field prime");
    }
  };

  func rpcHexNat(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    url : Text,
    method : Text,
    paramsJson : Text,
  ) : async Result.Result<Nat, Text> {
    let payload = switch (await rpcCall(ic, transform, httpCycles, url, method, paramsJson)) {
      case (#ok(p)) p;
      case (#err(e)) return #err(e);
    };

    switch (Json.extractStringAfterAny(payload, ["\"result\":\"", "\"result\": \""])) {
      case null #err("rpc result missing for method " # method);
      case (?hex) {
        switch (hexToNat(hex)) {
          case null #err("invalid hex result for method " # method # ": " # hex);
          case (?n) #ok(n);
        }
      }
    }
  };

  func rpcCall(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    url : Text,
    method : Text,
    paramsJson : Text,
  ) : async Result.Result<Text, Text> {
    let bodyText = "{" #
      "\"jsonrpc\":\"2.0\"," #
      "\"id\":1," #
      "\"method\":\"" # Json.escape(method) # "\"," #
      "\"params\":" # paramsJson #
      "}";

    let req : HttpTypes.HttpRequestArgs = {
      url;
      max_response_bytes = ?(1_000_000 : Nat64);
      method = #post;
      headers = [{ name = "Content-Type"; value = "application/json" }];
      body = ?Text.encodeUtf8(bodyText);
      transform = ?{
        function = transform;
        context = Blob.fromArray([]);
      };
    };

    let resp = await (with cycles = httpCycles) ic.http_request(req);
    let payload = switch (Text.decodeUtf8(resp.body)) {
      case null "";
      case (?t) t;
    };
    if (resp.status < 200 or resp.status >= 300) {
      return #err("rpc http status " # Nat.toText(resp.status) # ": " # payload);
    };
    #ok(payload)
  };

  func isBase(network : Text) : Bool {
    Text.toLowercase(Text.trim(network, #char ' ')) == "base"
  };

  func natToHex(n : Nat) : Text {
    if (n == 0) return "0x0";
    let table = [
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
    ];
    var x = n;
    var out = "";
    while (x > 0) {
      let d = x % 16;
      out := table[d] # out;
      x /= 16;
    };
    "0x" # out
  };

  func hexDigit(c : Char) : ?Nat {
    let n = Char.toNat32(c);
    if (n >= 48 and n <= 57) return ?Nat32.toNat(n - 48);
    if (n >= 65 and n <= 70) return ?Nat32.toNat(n - 55);
    if (n >= 97 and n <= 102) return ?Nat32.toNat(n - 87);
    null
  };

  func hexToNat(h : Text) : ?Nat {
    let t = Text.trim(h, #char ' ');
    let raw = switch (Text.stripStart(t, #text "0x")) {
      case (?v) v;
      case null switch (Text.stripStart(t, #text "0X")) {
        case (?v2) v2;
        case null t;
      };
    };
    if (Text.size(raw) == 0) return ?0;
    var acc : Nat = 0;
    for (c in raw.chars()) {
      switch (hexDigit(c)) {
        case null return null;
        case (?d) { acc := acc * 16 + d };
      }
    };
    ?acc
  };

  func resolveRpcUrl(network : Text, rpcUrl : ?Text) : Result.Result<Text, Text> {
    switch (rpcUrl) {
      case (?u) {
        let t = Text.trim(u, #char ' ');
        if (Text.size(t) > 0) return #ok(t);
      };
      case null {};
    };

    let n = Text.toLowercase(Text.trim(network, #char ' '));
    if (n == "ethereum" or n == "eth" or n == "mainnet") {
      return #ok("https://ethereum-rpc.publicnode.com");
    };
    if (n == "base") {
      return #ok("https://mainnet.base.org");
    };
    #err("unsupported network: " # network)
  };
}
