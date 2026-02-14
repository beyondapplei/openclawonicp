import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "kv.get";
    description = "Get current user's KV value by key.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"key\":{\"type\":\"string\"}},\"required\":[\"key\"],\"additionalProperties\":false}";
    argNames = ["key"];
    permission = #user;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 1) return #err("kv.get requires args: key");
    let key = Text.trim(args[0], #char ' ');
    if (Text.size(key) == 0) return #err("invalid key");
    #ok(deps.kvGet(key))
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
