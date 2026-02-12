import Result "mo:base/Result";

module {
  public type Provider = { #openai; #anthropic; #google };
  public type Role = { #system_; #user; #assistant; #tool };

  public type ChatMessage = {
    role : Role;
    content : Text;
    tsNs : Int;
  };

  public type SessionSummary = {
    id : Text;
    updatedAtNs : Int;
    messageCount : Nat;
  };

  public type SendOptions = {
    provider : Provider;
    model : Text;
    apiKey : Text;
    systemPrompt : ?Text;
    maxTokens : ?Nat;
    temperature : ?Float;
    skillNames : [Text];
    includeHistory : Bool;
  };

  public type SendOk = {
    assistant : ChatMessage;
    raw : ?Text;
  };

  public type SendResult = Result.Result<SendOk, Text>;
  public type ToolResult = Result.Result<Text, Text>;
}
