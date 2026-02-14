import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import ChannelRouter "../../channels/ChannelRouter";
import ChannelPluginRegistry "../../channels/plugins/PluginRegistry";
import HttpTypes "../../http/HttpTypes";
import Llm "../../llm/Llm";
import Sessions "../../core/Sessions";
import Store "../../core/Store";
import Types "../../core/Types";

module {
  public type InHttpRequest = ChannelRouter.InHttpRequest;
  public type InHttpResponse = ChannelRouter.InHttpResponse;

  public type Deps = {
    tgLlmOpts : ?Types.SendOptions;
    resolveApiKey : (provider : Types.Provider, providedApiKey : Text) -> Result.Result<Text, Text>;
    llmToolCallerFor : (callerPrincipal : Principal, sessionId : Text, includeOwnerTools : Bool) -> Sessions.ToolCaller;
    llmToolSpecsFor : (sessionId : Text, includeOwnerTools : Bool) -> [Sessions.ToolSpec];
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    canisterPrincipal : Principal;
    nowNs : () -> Int;
    modelCaller : Sessions.ModelCaller;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    discordProxySecret : ?Text;
    ic : Llm.Http;
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload;
    defaultHttpCycles : Nat;
  };

  public func routeQuery(req : InHttpRequest) : InHttpResponse {
    ChannelRouter.routeQuery(req, ChannelPluginRegistry.queryHandlers())
  };

  public func routeUpdate(req : InHttpRequest, deps : Deps) : async InHttpResponse {
    let tgOptsResolved : ?Types.SendOptions = switch (deps.tgLlmOpts) {
      case null null;
      case (?opts) {
        switch (deps.resolveApiKey(opts.provider, opts.apiKey)) {
          case (#err(_)) null;
          case (#ok(k)) {
            ?{
              provider = opts.provider;
              model = opts.model;
              apiKey = k;
              systemPrompt = opts.systemPrompt;
              maxTokens = opts.maxTokens;
              temperature = opts.temperature;
              skillNames = opts.skillNames;
              includeHistory = opts.includeHistory;
            }
          };
        }
      };
    };

    // Webhook senders are unauthenticated external users; keep owner tools disabled by default.
    let includeOwnerTools = false;
    let tgToolCaller = deps.llmToolCallerFor(deps.canisterPrincipal, "tg:channel", includeOwnerTools);
    let tgToolSpecs = deps.llmToolSpecsFor("tg:channel", includeOwnerTools);
    let dcToolCaller = deps.llmToolCallerFor(deps.canisterPrincipal, "dc:channel", includeOwnerTools);
    let dcToolSpecs = deps.llmToolSpecsFor("dc:channel", includeOwnerTools);

    await ChannelRouter.routeUpdate(req, ChannelPluginRegistry.updateHandlers({
      telegram = {
        tgBotToken = deps.tgBotToken;
        tgSecretToken = deps.tgSecretToken;
        tgLlmOpts = tgOptsResolved;
        users = deps.users;
        canisterPrincipal = deps.canisterPrincipal;
        nowNs = deps.nowNs;
        modelCaller = deps.modelCaller;
        toolCaller = tgToolCaller;
        toolSpecs = tgToolSpecs;
        ic = deps.ic;
        transformFn = deps.transformFn;
        defaultHttpCycles = deps.defaultHttpCycles;
      };
      discord = {
        llmOpts = tgOptsResolved;
        proxySecret = deps.discordProxySecret;
        users = deps.users;
        canisterPrincipal = deps.canisterPrincipal;
        nowNs = deps.nowNs;
        modelCaller = deps.modelCaller;
        toolCaller = dcToolCaller;
        toolSpecs = dcToolSpecs;
      };
    }))
  };
}
