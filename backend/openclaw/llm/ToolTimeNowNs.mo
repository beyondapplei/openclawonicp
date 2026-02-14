import Int "mo:base/Int";
import Text "mo:base/Text";

import ToolTypes "./ToolTypes";

module {
  public let spec : ToolTypes.ToolSpec = {
    name = "time.nowNs";
    description = "Get current canister time in nanoseconds.";
    parametersJson = "{\"type\":\"object\",\"properties\":{},\"required\":[],\"additionalProperties\":false}";
    argNames = [];
    permission = #user;
    exposeToLlm = true;
    exposeToApi = true;
  };

  public func run(_args : [Text], deps : ToolTypes.DispatchDeps) : async ToolTypes.ToolResult {
    #ok(Int.toText(deps.nowNs()))
  };

  public let handler : ToolTypes.ToolHandler = {
    name = spec.name;
    run = run;
  };
}
