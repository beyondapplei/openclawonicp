import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import ChannelRouter "./ChannelRouter";
import ChannelDock "./ChannelDock";
import HttpTypes "../http/HttpTypes";
import Llm "../llm/Llm";
import Sessions "../core/Sessions";
import Store "../core/Store";
import TelegramWebhook "../telegram/TelegramWebhook";
import Types "../core/Types";

module {
  public type HeaderField = ChannelRouter.HeaderField;
  public type InHttpRequest = ChannelRouter.InHttpRequest;
  public type InHttpResponse = ChannelRouter.InHttpResponse;

  public type Deps = {
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    canisterPrincipal : Principal;
    nowNs : () -> Int;
    modelCaller : Sessions.ModelCaller;
    toolCaller : Sessions.ToolCaller;
    toolSpecs : [Sessions.ToolSpec];
    ic : Llm.Http;
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload;
    defaultHttpCycles : Nat;
  };

  func isTelegramWebhook(req : InHttpRequest) : Bool {
    req.method == "POST" and Text.startsWith(req.url, #text(ChannelDock.telegram.webhookPrefix))
  };

  public func queryHandler() : ChannelRouter.QueryHandler {
    {
      canHandleQuery = isTelegramWebhook;
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
      canHandleUpdate = isTelegramWebhook;
      handleUpdate = func(req : InHttpRequest) : async InHttpResponse {
        await TelegramWebhook.handleTelegramWebhook(
          req,
          deps.tgBotToken,
          deps.tgSecretToken,
          deps.tgLlmOpts,
          deps.users,
          deps.canisterPrincipal,
          deps.nowNs,
          deps.modelCaller,
          deps.toolCaller,
          deps.toolSpecs,
          deps.ic,
          deps.transformFn,
          deps.defaultHttpCycles,
        )
      };
    }
  };
}
