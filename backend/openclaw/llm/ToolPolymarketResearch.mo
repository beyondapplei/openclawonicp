import Nat "mo:base/Nat";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "polymarket_research";
    description = "Fetch Polymarket market candidates plus related web headlines for betting research.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"topic\":{\"type\":\"string\",\"description\":\"Research topic, e.g. US election, fed rates, bitcoin ETF\"},\"market_limit\":{\"type\":\"integer\",\"minimum\":1,\"maximum\":20,\"description\":\"Optional; default 8\"},\"news_limit\":{\"type\":\"integer\",\"minimum\":1,\"maximum\":20,\"description\":\"Optional; default 8\"}},\"required\":[\"topic\"],\"additionalProperties\":false}";
    argNames = ["topic", "market_limit", "news_limit"];
    permission = #owner;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 1) return #err("polymarket_research requires args: topic");
    let topic = Text.trim(args[0], #char ' ');
    if (Text.size(topic) == 0) return #err("topic is required");

    let marketLimit = if (args.size() > 1 and Text.size(Text.trim(args[1], #char ' ')) > 0) {
      switch (Nat.fromText(Text.trim(args[1], #char ' '))) {
        case null return #err("invalid market_limit");
        case (?v) v;
      }
    } else {
      8
    };

    let newsLimit = if (args.size() > 2 and Text.size(Text.trim(args[2], #char ' ')) > 0) {
      switch (Nat.fromText(Text.trim(args[2], #char ' '))) {
        case null return #err("invalid news_limit");
        case (?v) v;
      }
    } else {
      8
    };

    switch (await deps.polymarketResearch(topic, marketLimit, newsLimit)) {
      case (#ok(v)) #ok(v);
      case (#err(e)) #err(e);
    }
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
