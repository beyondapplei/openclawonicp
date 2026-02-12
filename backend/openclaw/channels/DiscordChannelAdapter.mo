import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import ChannelRouter "./ChannelRouter";
import Json "../http/Json";
import Sessions "../core/Sessions";
import Store "../core/Store";
import Types "../core/Types";

module {
  public type InHttpRequest = ChannelRouter.InHttpRequest;
  public type InHttpResponse = ChannelRouter.InHttpResponse;

  public type Deps = {
    llmOpts : ?Types.SendOptions;
    proxySecret : ?Text;
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    canisterPrincipal : Principal;
    nowNs : () -> Int;
    modelCaller : Sessions.ModelCaller;
    toolCaller : Sessions.ToolCaller;
    toolSpecs : [Sessions.ToolSpec];
  };

  type ParsedIncoming = {
    channelId : Text;
    text : Text;
    isInteraction : Bool;
  };

  func isDiscordWebhook(req : InHttpRequest) : Bool {
    req.method == "POST" and Text.startsWith(req.url, #text "/discord/webhook")
  };

  public func queryHandler() : ChannelRouter.QueryHandler {
    {
      canHandleQuery = isDiscordWebhook;
      queryResponse = func() : InHttpResponse {
        {
          status_code = 200;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("ok");
          streaming_strategy = null;
          upgrade = ?true;
        }
      };
    }
  };

  public func updateHandler(deps : Deps) : ChannelRouter.UpdateHandler {
    {
      canHandleUpdate = isDiscordWebhook;
      handleUpdate = func(req : InHttpRequest) : async InHttpResponse {
        let bodyText = switch (Text.decodeUtf8(req.body)) {
          case null {
            return {
              status_code = 400;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("bad request");
              streaming_strategy = null;
              upgrade = null;
            };
          };
          case (?t) t;
        };

        switch (verifyRequest(req, deps.proxySecret)) {
          case (?resp) return resp;
          case null {};
        };

        if (isPing(bodyText)) {
          return {
            status_code = 200;
            headers = [("content-type", "application/json")];
            body = Text.encodeUtf8("{\"type\":1}");
            streaming_strategy = null;
            upgrade = null;
          };
        };

        switch (parseIncomingMessage(bodyText)) {
          case null {
            return {
              status_code = 200;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("ok");
              streaming_strategy = null;
              upgrade = null;
            };
          };
          case (?incoming) {
            let opts = switch (deps.llmOpts) {
              case null {
                return {
                  status_code = 503;
                  headers = [("content-type", "text/plain")];
                  body = Text.encodeUtf8("llm not configured");
                  streaming_strategy = null;
                  upgrade = null;
                };
              };
              case (?o) o;
            };

            let sessionId = "dc:" # incoming.channelId;
            let sendRes = await Sessions.send(
              deps.users,
              deps.canisterPrincipal,
              sessionId,
              incoming.text,
              opts,
              deps.nowNs,
              deps.modelCaller,
              ?deps.toolCaller,
              deps.toolSpecs,
            );

            if (incoming.isInteraction) {
              let content = switch (sendRes) {
                case (#ok(ok)) ok.assistant.content;
                case (#err(e)) "command failed: " # e;
              };
              return {
                status_code = 200;
                headers = [("content-type", "application/json")];
                body = Text.encodeUtf8(interactionMessageJson(content));
                streaming_strategy = null;
                upgrade = null;
              };
            };

            {
              status_code = 200;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("ok");
              streaming_strategy = null;
              upgrade = null;
            }
          };
        }
      };
    }
  };

  func verifyRequest(req : InHttpRequest, proxySecret : ?Text) : ?InHttpResponse {
    switch (proxySecret) {
      case null {
        ?{
          status_code = 503;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("discord signature verification not configured");
          streaming_strategy = null;
          upgrade = null;
        }
      };
      case (?secret) {
        let proxyHeader = headerGet(req.headers, "x-openclaw-discord-secret");
        if (proxyHeader != ?secret) {
          return ?{
            status_code = 401;
            headers = [("content-type", "text/plain")];
            body = Text.encodeUtf8("unauthorized");
            streaming_strategy = null;
            upgrade = null;
          };
        };
        let sig = headerGet(req.headers, "x-discord-signature-ed25519");
        let ts = headerGet(req.headers, "x-discord-signature-timestamp");
        if (isBlank(sig) or isBlank(ts)) {
          return ?{
            status_code = 401;
            headers = [("content-type", "text/plain")];
            body = Text.encodeUtf8("missing discord signature headers");
            streaming_strategy = null;
            upgrade = null;
          };
        };
        null
      };
    }
  };

  func isPing(body : Text) : Bool {
    Text.contains(body, #text "\"type\":1") or Text.contains(body, #text "\"type\": 1")
  };

  func parseIncomingMessage(body : Text) : ?ParsedIncoming {
    if (Text.contains(body, #text "\"bot\":true") or Text.contains(body, #text "\"bot\": true")) {
      return null;
    };

    let content = Json.extractStringAfterAny(body, ["\"content\":\"", "\"content\": \""]);
    let commandName = Json.extractStringAfterAny(body, ["\"name\":\"", "\"name\": \""]);
    let isInteraction = Text.contains(body, #text "\"type\":2") or Text.contains(body, #text "\"type\": 2");

    let text = switch (content, commandName) {
      case (?c, _) {
        let trimmed = Text.trim(c, #char ' ');
        if (Text.size(trimmed) == 0) return null;
        trimmed
      };
      case (null, ?name) {
        let trimmed = Text.trim(name, #char ' ');
        if (Text.size(trimmed) == 0) return null;
        let args = extractCommandArgs(body);
        if (Text.size(args) == 0) {
          "/" # trimmed
        } else {
          "/" # trimmed # " " # args
        }
      };
      case (null, null) return null;
    };

    let channelId = switch (Json.extractStringAfterAny(body, ["\"channel_id\":\"", "\"channel_id\": \""])) {
      case (?id) id;
      case null {
        switch (extractNatAfterAny(body, ["\"channel_id\":", "\"channel_id\": "])) {
          case (?n) Nat.toText(n);
          case null return null;
        }
      };
    };

    ?{ channelId; text; isInteraction }
  };

  func extractCommandArgs(body : Text) : Text {
    let values = Json.extractAllStringsAfterAny(body, ["\"value\":\"", "\"value\": \""]);
    var out = "";
    for (v in values.vals()) {
      let t = Text.trim(v, #char ' ');
      if (Text.size(t) > 0) {
        if (Text.size(out) == 0) {
          out := t;
        } else {
          out := out # " " # t;
        }
      }
    };
    out
  };

  func interactionMessageJson(text : Text) : Text {
    let safe = truncate(text, 1800);
    "{" #
      "\"type\":4," #
      "\"data\":{" #
      "\"content\":\"" # Json.escape(safe) # "\"" #
      "}" #
    "}"
  };

  func truncate(t : Text, maxChars : Nat) : Text {
    if (Text.size(t) <= maxChars) return t;
    var out = "";
    var i : Nat = 0;
    for (c in t.chars()) {
      if (i >= maxChars) return out # "…";
      out := out # Text.fromChar(c);
      i += 1;
    };
    out
  };

  func isBlank(v : ?Text) : Bool {
    switch (v) {
      case null true;
      case (?t) Text.size(Text.trim(t, #char ' ')) == 0;
    }
  };

  func headerGet(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
      if (Text.toLowercase(k) == Text.toLowercase(key)) return ?v;
    };
    null
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
}
