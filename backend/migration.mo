import Principal "mo:base/Principal";

import Store "./openclaw/core/Store";
import Types "./openclaw/core/Types";

module {
  public type V1 = {
    owner : ?Principal;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    usersStore : [(Principal, Store.UserStore)];
  };

  public type V2 = {
    owner : ?Principal;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    usersStore : [(Principal, Store.UserStore)];
    llmApiKeysEnc : [(Text, Text)];
  };

  public type V3 = {
    owner : ?Principal;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    usersStore : [(Principal, Store.UserStore)];
    llmApiKeysEnc : [(Text, Text)];
    discordProxySecret : ?Text;
  };

  public type V4 = {
    owner : ?Principal;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    usersStore : [(Principal, Store.UserStore)];
    llmApiKeysEnc : [(Text, Text)];
    discordProxySecret : ?Text;
    ckethBrokerCanisterText : ?Text;
  };

  public type V5 = {
    owner : ?Principal;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    usersStore : [(Principal, Store.UserStore)];
    llmApiKeysEnc : [(Text, Text)];
    discordProxySecret : ?Text;
    ckethIcpswapBrokerCanisterText : ?Text;
    ckethKongswapBrokerCanisterText : ?Text;
  };

  public type V6 = {
    owner : ?Principal;
    tgBotToken : ?Text;
    tgSecretToken : ?Text;
    tgLlmOpts : ?Types.SendOptions;
    usersStore : [(Principal, Store.UserStore)];
    llmApiKeysEnc : [(Text, Text)];
    discordProxySecret : ?Text;
    ckethIcpswapQuoteUrl : ?Text;
    ckethKongswapQuoteUrl : ?Text;
    ckethIcpswapBrokerCanisterText : ?Text;
    ckethKongswapBrokerCanisterText : ?Text;
  };

  public type State = {
    #v1 : V1;
    #v2 : V2;
    #v3 : V3;
    #v4 : V4;
    #v5 : V5;
    #v6 : V6;
  };

  public type Current = V6;

  public func capture(
    owner : ?Principal,
    tgBotToken : ?Text,
    tgSecretToken : ?Text,
    tgLlmOpts : ?Types.SendOptions,
    usersStore : [(Principal, Store.UserStore)],
    llmApiKeysEnc : [(Text, Text)],
    discordProxySecret : ?Text,
    ckethIcpswapQuoteUrl : ?Text,
    ckethKongswapQuoteUrl : ?Text,
    ckethIcpswapBrokerCanisterText : ?Text,
    ckethKongswapBrokerCanisterText : ?Text,
  ) : State {
    #v6({
      owner;
      tgBotToken;
      tgSecretToken;
      tgLlmOpts;
      usersStore;
      llmApiKeysEnc;
      discordProxySecret;
      ckethIcpswapQuoteUrl;
      ckethKongswapQuoteUrl;
      ckethIcpswapBrokerCanisterText;
      ckethKongswapBrokerCanisterText;
    })
  };

  public func migrate(state : State) : Current {
    switch (state) {
      case (#v1(v1)) {
        {
          owner = v1.owner;
          tgBotToken = v1.tgBotToken;
          tgSecretToken = v1.tgSecretToken;
          tgLlmOpts = v1.tgLlmOpts;
          usersStore = v1.usersStore;
          llmApiKeysEnc = [];
          discordProxySecret = null;
          ckethIcpswapQuoteUrl = null;
          ckethKongswapQuoteUrl = null;
          ckethIcpswapBrokerCanisterText = null;
          ckethKongswapBrokerCanisterText = null;
        }
      };
      case (#v6(v6)) v6;
      case (#v2(v2)) {
        {
          owner = v2.owner;
          tgBotToken = v2.tgBotToken;
          tgSecretToken = v2.tgSecretToken;
          tgLlmOpts = v2.tgLlmOpts;
          usersStore = v2.usersStore;
          llmApiKeysEnc = v2.llmApiKeysEnc;
          discordProxySecret = null;
          ckethIcpswapQuoteUrl = null;
          ckethKongswapQuoteUrl = null;
          ckethIcpswapBrokerCanisterText = null;
          ckethKongswapBrokerCanisterText = null;
        }
      };
      case (#v3(v3)) {
        {
          owner = v3.owner;
          tgBotToken = v3.tgBotToken;
          tgSecretToken = v3.tgSecretToken;
          tgLlmOpts = v3.tgLlmOpts;
          usersStore = v3.usersStore;
          llmApiKeysEnc = v3.llmApiKeysEnc;
          discordProxySecret = v3.discordProxySecret;
          ckethIcpswapQuoteUrl = null;
          ckethKongswapQuoteUrl = null;
          ckethIcpswapBrokerCanisterText = null;
          ckethKongswapBrokerCanisterText = null;
        }
      };
      case (#v4(v4)) {
        {
          owner = v4.owner;
          tgBotToken = v4.tgBotToken;
          tgSecretToken = v4.tgSecretToken;
          tgLlmOpts = v4.tgLlmOpts;
          usersStore = v4.usersStore;
          llmApiKeysEnc = v4.llmApiKeysEnc;
          discordProxySecret = v4.discordProxySecret;
          ckethIcpswapQuoteUrl = null;
          ckethKongswapQuoteUrl = null;
          ckethIcpswapBrokerCanisterText = v4.ckethBrokerCanisterText;
          ckethKongswapBrokerCanisterText = null;
        }
      };
      case (#v5(v5)) {
        {
          owner = v5.owner;
          tgBotToken = v5.tgBotToken;
          tgSecretToken = v5.tgSecretToken;
          tgLlmOpts = v5.tgLlmOpts;
          usersStore = v5.usersStore;
          llmApiKeysEnc = v5.llmApiKeysEnc;
          discordProxySecret = v5.discordProxySecret;
          ckethIcpswapQuoteUrl = null;
          ckethKongswapQuoteUrl = null;
          ckethIcpswapBrokerCanisterText = v5.ckethIcpswapBrokerCanisterText;
          ckethKongswapBrokerCanisterText = v5.ckethKongswapBrokerCanisterText;
        }
      };
    }
  };
}
