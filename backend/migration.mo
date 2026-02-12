import Principal "mo:base/Principal";

import Store "./openclaw/Store";
import Types "./openclaw/Types";

module {
  public type V1 = {
    owner : ?Principal;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    usersStore : [(Principal, Store.UserStore)];
  };

  public type State = {
    #v1 : V1;
  };

  public type Current = V1;

  public func capture(
    owner : ?Principal,
    tgBotToken : ?Text,
    tgSecretToken : ?Text,
    tgLlmOpts : ?Types.SendOptions,
    usersStore : [(Principal, Store.UserStore)],
  ) : State {
    #v1({
      owner;
      tgBotToken;
      tgSecretToken;
      tgLlmOpts;
      usersStore;
    })
  };

  public func migrate(state : State) : Current {
    switch (state) {
      case (#v1(v1)) v1;
    }
  };
}
