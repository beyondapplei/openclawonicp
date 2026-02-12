import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Char "mo:base/Char";
import Blob "mo:base/Blob";

import HttpTypes "../http/HttpTypes";
import Json "../http/Json";

module {
  public type BuyCkEthResult = Result.Result<Text, Text>;
  public type Http = actor { http_request : HttpTypes.HttpRequestArgs -> async HttpTypes.HttpResponsePayload };

  public type VenueConfig = {
    ic : Http;
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload;
    httpCycles : Nat;
    icpswapQuoteUrl : ?Text;
    kongswapQuoteUrl : ?Text;
    icpswapBroker : ?Text;
    kongswapBroker : ?Text;
  };

  public type BestQuote = {
    venue : Text;
    expectedIcpE8s : Nat64;
  };

  type CkEthVenueBroker = actor {
    quote_cketh : shared (Nat) -> async Result.Result<Nat64, Text>;
    buy_cketh : shared (Nat, Nat64) -> async Result.Result<Text, Text>;
  };

  public func buyBest(config : VenueConfig, amountCkEthText : Text, maxIcpE8s : Nat64) : async BuyCkEthResult {
    let amountWei = switch (parseCkEthToWei(amountCkEthText)) {
      case null return #err("invalid amount_cketh (examples: 1, 0.5, 1.25)");
      case (?v) v;
    };
    if (amountWei == 0) return #err("amount_cketh must be > 0");

    let bestQuote = await quoteBest(config, amountWei, amountCkEthText);
    let chosen = switch (bestQuote) {
      case (#err(e)) return #err(e);
      case (#ok(q)) q;
    };

    if (chosen.expectedIcpE8s > maxIcpE8s) {
      return #err(
        "best quote exceeds max_icp_e8s, venue=" # chosen.venue #
        ", quote=" # Nat64.toText(chosen.expectedIcpE8s) #
        ", max=" # Nat64.toText(maxIcpE8s)
      );
    };

    let brokerTextOpt = if (chosen.venue == "icpswap") {
      config.icpswapBroker
    } else {
      config.kongswapBroker
    };
    let brokerText = switch (brokerTextOpt) {
      case null {
        return #ok(
          "venue=" # chosen.venue #
          "; quote_icp_e8s=" # Nat64.toText(chosen.expectedIcpE8s) #
          "; quote_only=true; execute_skipped=no_broker"
        )
      };
      case (?v) v;
    };

    let broker = switch (openVenueBroker(brokerText)) {
      case (#err(e)) return #err(e);
      case (#ok(b)) b;
    };

    let buyRes = try {
      await broker.buy_cketh(amountWei, maxIcpE8s)
    } catch (e) {
      return #err("buy failed on " # chosen.venue # ": " # Error.message(e));
    };

    switch (buyRes) {
      case (#err(e)) #err(chosen.venue # " buy error: " # e);
      case (#ok(v)) {
        #ok(
          "venue=" # chosen.venue #
          "; quote_icp_e8s=" # Nat64.toText(chosen.expectedIcpE8s) #
          "; result=" # v
        )
      };
    }
  };

  public func buyOne(config : VenueConfig, maxIcpE8s : Nat64) : async BuyCkEthResult {
    await buyBest(config, "1", maxIcpE8s)
  };

  func quoteBest(config : VenueConfig, amountWei : Nat, amountCkEthText : Text) : async Result.Result<BestQuote, Text> {
    var best : ?BestQuote = null;

    switch (config.icpswapQuoteUrl) {
      case null {};
      case (?urlTemplate) {
        switch (await quoteOneVenue(config, "icpswap", urlTemplate, amountWei, amountCkEthText)) {
          case (#ok(q)) { best := pickBest(best, q) };
          case (#err(_)) {};
        }
      };
    };

    switch (config.kongswapQuoteUrl) {
      case null {};
      case (?urlTemplate) {
        switch (await quoteOneVenue(config, "kongswap", urlTemplate, amountWei, amountCkEthText)) {
          case (#ok(q)) { best := pickBest(best, q) };
          case (#err(_)) {};
        }
      };
    };

    switch (best) {
      case null #err("no quote available (configure icpswap/kongswap brokers)");
      case (?q) #ok(q);
    }
  };

  func pickBest(current : ?BestQuote, candidate : BestQuote) : ?BestQuote {
    switch (current) {
      case null ?candidate;
      case (?c) {
        if (candidate.expectedIcpE8s < c.expectedIcpE8s) ?candidate else ?c
      };
    }
  };

  func quoteOneVenue(
    config : VenueConfig,
    venue : Text,
    quoteUrlTemplate : Text,
    amountWei : Nat,
    amountCkEthText : Text,
  ) : async Result.Result<BestQuote, Text> {
    let quoteUrl = buildQuoteUrl(quoteUrlTemplate, amountWei, amountCkEthText);
    let req : HttpTypes.HttpRequestArgs = {
      url = quoteUrl;
      max_response_bytes = ?(200_000 : Nat64);
      method = #get;
      headers = [];
      body = null;
      transform = ?{ function = config.transformFn; context = Blob.fromArray([]) };
    };

    let resp = try {
      await (with cycles = config.httpCycles) config.ic.http_request(req)
    } catch (e) {
      return #err(venue # " quote http failed: " # Error.message(e));
    };
    if (resp.status < 200 or resp.status >= 300) {
      return #err(venue # " quote http status " # Nat.toText(resp.status));
    };

    let raw = switch (Text.decodeUtf8(resp.body)) {
      case null return #err(venue # " quote body is not utf-8");
      case (?t) t;
    };
    let expectedIcpE8s = switch (parseQuoteIcpE8s(raw)) {
      case null return #err(venue # " quote parse failed");
      case (?v) v;
    };
    #ok({ venue; expectedIcpE8s })
  };

  func buildQuoteUrl(template : Text, amountWei : Nat, amountCkEthText : Text) : Text {
    let withWei = replaceAll(template, "{amountWei}", Nat.toText(amountWei));
    replaceAll(withWei, "{amount}", amountCkEthText)
  };

  func replaceAll(text : Text, token : Text, value : Text) : Text {
    Text.join(value, Text.split(text, #text token))
  };

  func parseQuoteIcpE8s(raw : Text) : ?Nat64 {
    let trimmed = Text.trim(raw, #char ' ');
    switch (nat64FromText(trimmed)) {
      case (?v) return ?v;
      case null {};
    };

    let strVal = Json.extractStringAfterAny(trimmed, [
      "\"expectedIcpE8s\":\"",
      "\"icp_e8s\":\"",
      "\"amountOutE8s\":\"",
      "\"quoteIcpE8s\":\"",
    ]);
    switch (strVal) {
      case (?s) {
        switch (nat64FromText(Text.trim(s, #char ' '))) {
          case (?v) return ?v;
          case null {};
        }
      };
      case null {};
    };

    let natVal = extractNatAfterAny(trimmed, [
      "\"expectedIcpE8s\":",
      "\"expectedIcpE8s\": ",
      "\"icp_e8s\":",
      "\"icp_e8s\": ",
      "\"amountOutE8s\":",
      "\"amountOutE8s\": ",
      "\"quoteIcpE8s\":",
      "\"quoteIcpE8s\": ",
    ]);
    switch (natVal) {
      case null null;
      case (?n) if (n > 18_446_744_073_709_551_615) null else ?Nat64.fromNat(n);
    }
  };

  func nat64FromText(text : Text) : ?Nat64 {
    switch (Nat.fromText(text)) {
      case null null;
      case (?n) if (n > 18_446_744_073_709_551_615) null else ?Nat64.fromNat(n);
    }
  };

  func extractNatAfterAny(raw : Text, needles : [Text]) : ?Nat {
    for (n in needles.vals()) {
      switch (extractNatAfter(raw, n)) {
        case null {};
        case (?v) return ?v;
      }
    };
    null
  };

  func extractNatAfter(raw : Text, needle : Text) : ?Nat {
    let it = Text.split(raw, #text needle);
    ignore it.next();
    switch (it.next()) {
      case null null;
      case (?after) readNatPrefix(after);
    }
  };

  func readNatPrefix(t : Text) : ?Nat {
    var acc : Nat = 0;
    var seen = false;
    for (c in t.chars()) {
      if (c >= '0' and c <= '9') {
        seen := true;
        acc := acc * 10 + Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
      } else {
        if (seen) return ?acc;
      }
    };
    if (seen) ?acc else null
  };

  func openVenueBroker(brokerCanisterText : Text) : Result.Result<CkEthVenueBroker, Text> {
    let p = Text.trim(brokerCanisterText, #char ' ');
    if (Text.size(p) == 0) return #err("invalid broker canister principal");
    #ok(actor (p))
  };

  func parseCkEthToWei(rawText : Text) : ?Nat {
    let text = Text.trim(rawText, #char ' ');
    if (Text.size(text) == 0) return null;

    let parts = Text.split(text, #char '.');
    let wholePart = switch (parts.next()) {
      case null return null;
      case (?v) v;
    };
    let fracOpt = parts.next();
    if (parts.next() != null) return null;

    let whole = switch (parseDigitsOrEmpty(wholePart, true)) {
      case null return null;
      case (?v) v;
    };

    let fracAndPad = switch (fracOpt) {
      case null ?0;
      case (?f) {
        if (Text.size(f) > 18) return null;
        let frac = switch (parseDigitsOrEmpty(f, false)) {
          case null return null;
          case (?v) v;
        };
        ?(frac * pow10(18 - Text.size(f)))
      };
    };

    switch (fracAndPad) {
      case null null;
      case (?fracWei) ?(whole * pow10(18) + fracWei);
    }
  };

  func parseDigitsOrEmpty(text : Text, allowEmpty : Bool) : ?Nat {
    if (Text.size(text) == 0) {
      if (allowEmpty) return ?0 else return null;
    };
    var acc : Nat = 0;
    for (c in text.chars()) {
      if (c < '0' or c > '9') return null;
      let d = Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
      acc := acc * 10 + d;
    };
    ?acc
  };

  func pow10(n : Nat) : Nat {
    var v : Nat = 1;
    var i : Nat = 0;
    while (i < n) {
      v *= 10;
      i += 1;
    };
    v
  };
}
