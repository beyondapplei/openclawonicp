import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "kv.put";
    description = "Write current user's KV value by key.";
    parametersJson = "{\"type\":\"object\",\"properties\":{\"key\":{\"type\":\"string\"},\"value\":{\"type\":\"string\"}},\"required\":[\"key\",\"value\"],\"additionalProperties\":false}";
    argNames = ["key", "value"];
    permission = #user;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    if (args.size() < 2) return #err("kv.put requires args: key, value");
    let key = Text.trim(args[0], #char ' ');
    if (Text.size(key) == 0) return #err("invalid key");
    deps.kvPut(key, args[1]);
    #ok("ok")
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
