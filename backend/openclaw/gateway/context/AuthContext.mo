import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

module {
  public type ResolveApiKeyFn<Provider> = (
    provider : Provider,
    providedApiKey : Text,
  ) -> Result.Result<Text, Text>;

  public func assertAuthenticated(caller : Principal) {
    if (Principal.isAnonymous(caller)) {
      Debug.trap("login required")
    };
  };

  public func isOwner(owner : ?Principal, caller : Principal) : Bool {
    switch (owner) {
      case null false;
      case (?o) o == caller;
    }
  };

  // Returns next owner state (first authenticated caller can claim owner).
  public func assertOwner(owner : ?Principal, caller : Principal) : ?Principal {
    assertAuthenticated(caller);
    switch (owner) {
      case null ?caller;
      case (?o) {
        if (o != caller) { Debug.trap("not authorized") };
        owner
      };
    }
  };

  public func assertOwnerQuery(owner : ?Principal, caller : Principal) {
    switch (owner) {
      case null { Debug.trap("not authorized") };
      case (?o) {
        if (o != caller) { Debug.trap("not authorized") };
      };
    }
  };

  public func resolveApiKeyForCaller<Provider>(
    owner : ?Principal,
    caller : Principal,
    provider : Provider,
    providedApiKey : Text,
    resolveApiKey : ResolveApiKeyFn<Provider>,
  ) : Result.Result<Text, Text> {
    if (isOwner(owner, caller)) {
      return resolveApiKey(provider, providedApiKey);
    };
    let provided = Text.trim(providedApiKey, #char ' ');
    if (Text.size(provided) == 0) {
      #err("apiKey is required for non-owner caller")
    } else {
      #ok(provided)
    }
  };
}
