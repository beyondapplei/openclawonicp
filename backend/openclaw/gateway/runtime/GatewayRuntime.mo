import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Sessions "../../core/Sessions";
import Store "../../core/Store";
import Types "../../core/Types";
import LlmToolRouter "../../llm/LlmToolRouter";

module {
  public type Deps = {
    users : TrieMap.TrieMap<Principal, Store.UserState>;
    nowNs : () -> Int;
    callModel : (
      provider : Types.Provider,
      model : Text,
      apiKey : Text,
      sysPrompt : Text,
      history : [Types.ChatMessage],
      toolSpecs : [Sessions.ToolSpec],
      maxTokens : ?Nat,
      temperature : ?Float,
    ) -> async Result.Result<Text, Text>;
    sendIcp : (toPrincipalText : Text, amountE8s : Nat64) -> async Result.Result<Nat, Text>;
    sendEth : (network : Text, toAddress : Text, amountWei : Nat) -> async Result.Result<Text, Text>;
    sendErc20 : (
      network : Text,
      tokenAddress : Text,
      toAddress : Text,
      amount : Nat,
    ) -> async Result.Result<Text, Text>;
    buyErc20Uniswap : (
      network : Text,
      routerAddress : Text,
      tokenInAddress : Text,
      tokenOutAddress : Text,
      fee : Nat,
      amountIn : Nat,
      amountOutMinimum : Nat,
      deadline : Nat,
      sqrtPriceLimitX96 : Nat,
    ) -> async Result.Result<Text, Text>;
    swapErc20Uniswap : (
      network : Text,
      routerAddress : Text,
      tokenInAddress : Text,
      tokenOutAddress : Text,
      fee : Nat,
      amountIn : Nat,
      amountOutMinimum : Nat,
      deadline : Nat,
      sqrtPriceLimitX96 : Nat,
      autoApprove : Bool,
    ) -> async Result.Result<Text, Text>;
    buyUni : (
      network : Text,
      amountUniBase : Nat,
      slippageBps : Nat,
      deadline : Nat,
    ) -> async Result.Result<Text, Text>;
    polymarketResearch : (
      topic : Text,
      marketLimit : Nat,
      newsLimit : Nat,
    ) -> async Result.Result<Text, Text>;
    sendTg : (chatId : Nat, messageText : Text) -> async Result.Result<(), Text>;
    buyCkEth : (amountCkEthText : Text, maxIcpE8s : Nat64) -> async Result.Result<Text, Text>;
  };

  public func modelCaller(
    deps : Deps,
    provider : Types.Provider,
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [Types.ChatMessage],
    toolSpecs : [Sessions.ToolSpec],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) : async Result.Result<Text, Text> {
    await deps.callModel(provider, model, apiKey, sysPrompt, history, toolSpecs, maxTokens, temperature)
  };

  public func llmToolSpecsFor(sessionId : Text, includeOwnerTools : Bool) : [Sessions.ToolSpec] {
    let filter = resolveToolFilter(#llm, sessionId);
    LlmToolRouter.listSpecs(#llm, includeOwnerTools, ?filter)
  };

  public func runTool(
    deps : Deps,
    callerPrincipal : Principal,
    surface : LlmToolRouter.Surface,
    filter : ?LlmToolRouter.ToolFilter,
    includeOwnerTools : Bool,
    name : Text,
    args : [Text],
  ) : async Types.ToolResult {
    let user = Store.getOrInitUser(deps.users, callerPrincipal);
    await LlmToolRouter.dispatch(
      surface,
      includeOwnerTools,
      filter,
      name,
      args,
      deps.sendIcp,
      deps.sendEth,
      deps.sendErc20,
      deps.buyErc20Uniswap,
      deps.swapErc20Uniswap,
      deps.buyUni,
      deps.polymarketResearch,
      deps.sendTg,
      deps.buyCkEth,
      func(key : Text) : Text {
        switch (user.kv.get(key)) {
          case null "";
          case (?v) v;
        }
      },
      func(key : Text, value : Text) {
        user.kv.put(key, value);
      },
      deps.nowNs,
    )
  };

  public func llmToolCallerFor(
    deps : Deps,
    callerPrincipal : Principal,
    sessionId : Text,
    includeOwnerTools : Bool,
  ) : Sessions.ToolCaller {
    let filter = resolveToolFilter(#llm, sessionId);
    func(name : Text, args : [Text]) : async Types.ToolResult {
      await runTool(deps, callerPrincipal, #llm, ?filter, includeOwnerTools, name, args)
    }
  };

  public func apiToolCallerFor(deps : Deps, callerPrincipal : Principal, includeOwnerTools : Bool) : Sessions.ToolCaller {
    func(name : Text, args : [Text]) : async Types.ToolResult {
      await runTool(deps, callerPrincipal, #api, null, includeOwnerTools, name, args)
    }
  };

  func resolveToolFilter(surface : LlmToolRouter.Surface, sessionId : Text) : LlmToolRouter.ToolFilter {
    switch (surface) {
      case (#api) {
        {
          profile = null;
          allow = [];
          deny = [];
        }
      };
      case (#llm) {
        let sid = Text.toLowercase(Text.trim(sessionId, #char ' '));
        if (Text.startsWith(sid, #text "tg:")) {
          // Telegram sessions can use messaging tools but avoid wallet tools by default.
          {
            profile = ?#messaging;
            allow = [];
            deny = [];
          }
        } else if (Text.startsWith(sid, #text "dc:")) {
          // Discord webhook replies are adapter-driven; keep model tools minimal.
          {
            profile = ?#minimal;
            allow = [];
            deny = [];
          }
        } else {
          {
            profile = null;
            allow = [];
            deny = [];
          }
        }
      };
    }
  };
}
