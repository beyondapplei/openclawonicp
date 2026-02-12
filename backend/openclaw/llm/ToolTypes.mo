import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";

module {
  public type ToolSpec = {
    name : Text;
    argsHint : Text;
    rule : Text;
  };

  public type ToolResult = Result.Result<Text, Text>;
  public type SendIcpFn = (toPrincipalText : Text, amountE8s : Nat64) -> async Result.Result<Nat, Text>;
  public type SendEthFn = (network : Text, toAddress : Text, amountWei : Nat) -> async Result.Result<Text, Text>;
  public type SendTgFn = (chatId : Nat, text : Text) -> async Result.Result<(), Text>;
  public type BuyCkEthFn = (amountCkEthText : Text, maxIcpE8s : Nat64) -> async Result.Result<Text, Text>;

  public type DispatchDeps = {
    sendIcp : SendIcpFn;
    sendEth : SendEthFn;
    sendTg : SendTgFn;
    buyCkEth : BuyCkEthFn;
  };

  public type ToolHandler = {
    name : Text;
    run : (args : [Text], deps : DispatchDeps) -> async ToolResult;
  };
}
