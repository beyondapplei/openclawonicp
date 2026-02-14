import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import HttpTypes "../../http/HttpTypes";
import Llm "../../llm/Llm";
import Types "../../core/Types";

module {
  public type Deps = {
    ic : Llm.Http;
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload;
    defaultHttpCycles : Nat;
    assertAuthenticated : (caller : Principal) -> ();
    resolveApiKeyForCaller : (caller : Principal, provider : Types.Provider, providedApiKey : Text) -> Result.Result<Text, Text>;
  };

  public func list(deps : Deps, caller : Principal, provider : Types.Provider, apiKey : Text) : async Result.Result<[Text], Text> {
    deps.assertAuthenticated(caller);
    let resolvedApiKey = switch (deps.resolveApiKeyForCaller(caller, provider, apiKey)) {
      case (#err(e)) return #err(e);
      case (#ok(k)) k;
    };
    await Llm.listModels(deps.ic, deps.transformFn, deps.defaultHttpCycles, provider, resolvedApiKey)
  };
}
