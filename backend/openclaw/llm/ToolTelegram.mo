import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "tg_send_message";
    description = "Send a Telegram message via configured bot token.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"chat_id\":{\"type\":\"integer\",\"minimum\":1},\"text\":{\"type\":\"string\"}},\"required\":[\"chat_id\",\"text\"],\"additionalProperties\":false}";
    argNames = ["chat_id", "text"];
    permission = #owner;
    exposeToLlm = true;
    exposeToApi = true;
  };

  func joinArgsFrom(args : [Text], start : Nat) : Text {
    if (args.size() <= start) return "";
    let b = Buffer.Buffer<Text>(args.size() - start);
    var i = start;
    while (i < args.size()) {
      b.add(args[i]);
      i += 1;
    };
    Text.join("|", b.vals())
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 2) return #err("tg_send_message requires args: chat_id, text");
    let chatId : Nat = switch (Nat.fromText(Text.trim(args[0], #char ' '))) {
      case null return #err("invalid chat_id");
      case (?v) v;
    };
    let messageText = Text.trim(joinArgsFrom(args, 1), #char ' ');
    if (Text.size(messageText) == 0) return #err("empty text");

    switch (await deps.sendTg(chatId, messageText)) {
      case (#ok(_)) #ok("ok");
      case (#err(e)) #err(e);
    }
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
