import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";

module {
  public type ToolPermission = { #user; #owner };

  public type ToolSpec = {
    name : Text;
    description : Text;
    // JSON object schema string, embedded directly in provider tool definitions.
    parametersJson : Text;
    // Positional argument order used by local dispatcher/hook/tools_invoke.
    argNames : [Text];
    permission : ToolPermission;
    exposeToLlm : Bool;
    exposeToApi : Bool;
  };

  public type ToolResult = Result.Result<Text, Text>;
  public type SendIcpFn = (toPrincipalText : Text, amountE8s : Nat64) -> async Result.Result<Nat, Text>;
  public type SendEthFn = (network : Text, toAddress : Text, amountWei : Nat) -> async Result.Result<Text, Text>;
  public type SendErc20Fn = (
    network : Text,
    tokenAddress : Text,
    toAddress : Text,
    amount : Nat,
  ) -> async Result.Result<Text, Text>;
  public type BuyErc20UniswapFn = (
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
  public type SwapErc20UniswapFn = (
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
  public type BuyUniFn = (
    network : Text,
    amountUniBase : Nat,
    slippageBps : Nat,
    deadline : Nat,
  ) -> async Result.Result<Text, Text>;
  public type PolymarketResearchFn = (
    topic : Text,
    marketLimit : Nat,
    newsLimit : Nat,
  ) -> async Result.Result<Text, Text>;
  public type SendTgFn = (chatId : Nat, text : Text) -> async Result.Result<(), Text>;
  public type BuyCkEthFn = (amountCkEthText : Text, maxIcpE8s : Nat64) -> async Result.Result<Text, Text>;
  public type KvGetFn = (key : Text) -> Text;
  public type KvPutFn = (key : Text, value : Text) -> ();
  public type NowNsFn = () -> Int;

  public type DispatchDeps = {
    sendIcp : SendIcpFn;
    sendEth : SendEthFn;
    sendErc20 : SendErc20Fn;
    buyErc20Uniswap : BuyErc20UniswapFn;
    swapErc20Uniswap : SwapErc20UniswapFn;
    buyUni : BuyUniFn;
    polymarketResearch : PolymarketResearchFn;
    sendTg : SendTgFn;
    buyCkEth : BuyCkEthFn;
    kvGet : KvGetFn;
    kvPut : KvPutFn;
    nowNs : NowNsFn;
  };

  public type ToolHandler = {
    name : Text;
    run : (args : [Text], deps : DispatchDeps) -> async ToolResult;
  };
}
