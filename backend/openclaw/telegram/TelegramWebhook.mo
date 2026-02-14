import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import HttpTypes "../http/HttpTypes";
import Llm "../llm/Llm";
import Sessions "../core/Sessions";
import Store "../core/Store";
import Dispatch "../auto_reply/Dispatch";
import ChannelDock "../channels/ChannelDock";
import Telegram "./Telegram";
import Types "../core/Types";

module {
  public type HeaderField = (Text, Text);
  public type InHttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };
  public type InHttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
    streaming_strategy : ?{
      #Callback : {
        callback : shared query () -> async ();
        token : Blob;
      }
    };
    upgrade : ?Bool;
  };

  public type ModelCaller = Sessions.ModelCaller;
  public type ToolCaller = Sessions.ToolCaller;
  public type ToolSpec = Sessions.ToolSpec;

  public func handleTelegramWebhook(
    req : InHttpRequest,
    tgBotToken : ?Text,
    tgSecretToken : ?Text,
    tgLlmOpts : ?Types.SendOptions,
    users : TrieMap.TrieMap<Principal, Store.UserState>,
    canisterPrincipal : Principal,
    nowNs : () -> Int,
    modelCaller : ModelCaller,
    toolCaller : ToolCaller,
    toolSpecs : [ToolSpec],
    ic : Llm.Http,
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    defaultHttpCycles : Nat,
  ) : async InHttpResponse {
    if (not (req.method == "POST" and Text.startsWith(req.url, #text "/tg/webhook"))) {
      return {
        status_code = 404;
        headers = [("content-type", "text/plain")];
        body = Text.encodeUtf8("not found");
        streaming_strategy = null;
        upgrade = null;
      };
    };

    switch (tgSecretToken) {
      case null {};
      case (?secret) {
        let hdr = headerGet(req.headers, "x-telegram-bot-api-secret-token");
        if (hdr != ?secret) {
          return {
            status_code = 401;
            headers = [("content-type", "text/plain")];
            body = Text.encodeUtf8("unauthorized");
            streaming_strategy = null;
            upgrade = null;
          };
        };
      };
    };

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

    let parsed = Telegram.parseUpdate(bodyText);
    switch (parsed) {
      case null {
        return {
          status_code = 200;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("ok");
          streaming_strategy = null;
          upgrade = null;
        };
      };
      case (?u) {
        let token = switch (tgBotToken) {
          case null {
            return {
              status_code = 503;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("telegram not configured");
              streaming_strategy = null;
              upgrade = null;
            };
          };
          case (?t) t;
        };

        let opts = switch (tgLlmOpts) {
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

        let sessionId = ChannelDock.sessionIdFor(ChannelDock.telegram, Nat.toText(u.chatId));
        let sendRes = await Dispatch.dispatchInboundMessage({
          users = users;
          caller = canisterPrincipal;
          sessionId = sessionId;
          message = u.text;
          opts = opts;
          nowNs = nowNs;
          modelCaller = modelCaller;
          toolCaller = ?toolCaller;
          toolSpecs = toolSpecs;
        });
        switch (sendRes) {
          case (#err(_)) {};
          case (#ok(ok)) {
            ignore await Telegram.sendMessage(ic, transformFn, defaultHttpCycles, token, u.chatId, ok.assistant.content);
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

  func headerGet(headers : [HeaderField], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
      if (Text.toLowercase(k) == Text.toLowercase(key)) return ?v;
    };
    null
  };
}
