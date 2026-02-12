import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";

import HttpTypes "./HttpTypes";
import Json "./Json";

module {
  public type Http = actor { http_request : HttpTypes.HttpRequestArgs -> async HttpTypes.HttpResponsePayload };

  public type ParsedUpdate = {
    chatId : Nat;
    text : Text;
  };

  public func parseUpdate(body : Text) : ?ParsedUpdate {
    // Very small parser for Telegram Update JSON.
    // We look for first occurrence of "chat" then "id", and first "text".
    // Split to get segment after first "chat".
    let it = Text.split(body, #text "\"chat\"");
    ignore it.next();
    let seg = switch (it.next()) { case null return null; case (?s) s };

    let chatId = extractNatAfterAny(seg, ["\"id\":", "\"id\": "]);
    let text = Json.extractStringAfterAny(body, ["\"text\":\"", "\"text\": \""]);

    switch (chatId, text) {
      case (?cid, ?t) ?{ chatId = cid; text = t };
      case _ null;
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
        acc := acc * 10 + (Nat32.toNat(Char.toNat32(c) - Char.toNat32('0')));
      } else {
        if (seen) return ?acc;
      }
    };
    if (seen) ?acc else null
  };

  public func sendMessage(
    ic : Http,
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    botToken : Text,
    chatId : Nat,
    text : Text,
  ) : async Result.Result<(), Text> {
    let url = "https://api.telegram.org/bot" # botToken # "/sendMessage";
    let headers : [HttpTypes.HttpHeader] = [
      { name = "Content-Type"; value = "application/json" },
    ];

    let safeText = truncate(text, 3500);
    let bodyText = "{" #
      "\"chat_id\":" # Nat.toText(chatId) # "," #
      "\"text\":\"" # Json.escape(safeText) # "\"" #
      "}";

    let req : HttpTypes.HttpRequestArgs = {
      url;
      max_response_bytes = ?(200_000 : Nat64);
      method = #post;
      headers;
      body = ?Text.encodeUtf8(bodyText);
      transform = ?{ function = transformFn; context = Blob.fromArray([]) };
    };

    let resp = await (with cycles = httpCycles) ic.http_request(req);
    if (resp.status < 200 or resp.status >= 300) {
      let body = switch (Text.decodeUtf8(resp.body)) { case null ""; case (?t) t };
      return #err("telegram http status " # Nat.toText(resp.status) # ": " # body);
    };
    #ok(())
  };

  public func setWebhook(
    ic : Http,
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    botToken : Text,
    webhookUrl : Text,
    secretToken : ?Text,
  ) : async Result.Result<Text, Text> {
    let url = "https://api.telegram.org/bot" # botToken # "/setWebhook";
    let headers : [HttpTypes.HttpHeader] = [
      { name = "Content-Type"; value = "application/json" },
    ];

    let bodyText = "{" #
      "\"url\":\"" # Json.escape(webhookUrl) # "\"" #
      (switch (secretToken) {
        case null "";
        case (?s) ",\"secret_token\":\"" # Json.escape(s) # "\"";
      }) #
      "}";

    let req : HttpTypes.HttpRequestArgs = {
      url;
      max_response_bytes = ?(200_000 : Nat64);
      method = #post;
      headers;
      body = ?Text.encodeUtf8(bodyText);
      transform = ?{ function = transformFn; context = Blob.fromArray([]) };
    };

    let resp = await (with cycles = httpCycles) ic.http_request(req);
    if (resp.status < 200 or resp.status >= 300) {
      let body = switch (Text.decodeUtf8(resp.body)) { case null ""; case (?t) t };
      return #err("telegram http status " # Nat.toText(resp.status) # ": " # body);
    };

    let raw = switch (Text.decodeUtf8(resp.body)) { case null ""; case (?t) t };
    #ok(raw)
  };

  func truncate(t : Text, maxChars : Nat) : Text {
    if (Text.size(t) <= maxChars) return t;
    // Text.size is characters; take first maxChars.
    let buf = Buffer.Buffer<Text>(maxChars + 1);
    var i : Nat = 0;
    for (c in t.chars()) {
      if (i >= maxChars) return Text.join("", buf.vals()) # "…";
      buf.add(Text.fromChar(c));
      i += 1;
    };
    Text.join("", buf.vals())
  };
}
