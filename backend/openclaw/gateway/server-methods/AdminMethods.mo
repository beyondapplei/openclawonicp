import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import Types "../../core/Types";

module {
  public type Provider = Types.Provider;
  public type SendOptions = Types.SendOptions;

  public type TgStatus = {
    configured : Bool;
    hasSecret : Bool;
    hasLlmConfig : Bool;
  };

  public type DiscordStatus = {
    configured : Bool;
    hasProxySecret : Bool;
    hasLlmConfig : Bool;
  };

  public type CkEthStatus = {
    hasIcpswapQuoteUrl : Bool;
    hasKongswapQuoteUrl : Bool;
    hasIcpswapBroker : Bool;
    hasKongswapBroker : Bool;
  };

  public func setTg(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    botToken : Text,
    secretToken : ?Text,
    setState : (?Text, ?Text) -> (),
  ) {
    assertOwner(caller);
    setState(?Text.trim(botToken, #char ' '), secretToken);
  };

  public func setLlmOpts(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    opts : SendOptions,
    setState : (?SendOptions) -> (),
  ) {
    assertOwner(caller);
    setState(?opts);
  };

  public func setDiscord(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    proxySecret : ?Text,
    setState : (?Text) -> (),
  ) {
    assertOwner(caller);
    setState(normalizeOptText(proxySecret));
  };

  public func setCkethBroker(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    canisterText : ?Text,
    setState : (?Text) -> (),
  ) {
    assertOwner(caller);
    setState(normalizeOptText(canisterText));
  };

  public func setCkethBrokers(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    icpswapCanisterText : ?Text,
    kongswapCanisterText : ?Text,
    setState : (?Text, ?Text) -> (),
  ) {
    assertOwner(caller);
    setState(normalizeOptText(icpswapCanisterText), normalizeOptText(kongswapCanisterText));
  };

  public func setCkethQuoteSources(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    icpswapQuoteUrl : ?Text,
    kongswapQuoteUrl : ?Text,
    setState : (?Text, ?Text) -> (),
  ) {
    assertOwner(caller);
    setState(normalizeOptText(icpswapQuoteUrl), normalizeOptText(kongswapQuoteUrl));
  };

  public func setProviderApiKey(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    provider : Provider,
    apiKey : Text,
    setKey : (provider : Provider, apiKey : Text) -> (),
  ) {
    assertOwner(caller);
    setKey(provider, apiKey);
  };

  public func hasProviderApiKey(
    assertOwnerQuery : (caller : Principal) -> (),
    caller : Principal,
    provider : Provider,
    hasKey : (provider : Provider) -> Bool,
  ) : Bool {
    assertOwnerQuery(caller);
    hasKey(provider)
  };

  public func tgSetWebhook(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    webhookUrl : Text,
    getBotToken : () -> ?Text,
    getSecretToken : () -> ?Text,
    setWebhook : (botToken : Text, webhookUrl : Text, secretToken : ?Text) -> async Result.Result<Text, Text>,
  ) : async Result.Result<Text, Text> {
    assertOwner(caller);
    switch (getBotToken()) {
      case null #err("telegram bot token not configured");
      case (?token) await setWebhook(token, webhookUrl, getSecretToken());
    }
  };

  public func tgStatus(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    getBotToken : () -> ?Text,
    getSecretToken : () -> ?Text,
    getLlmOpts : () -> ?SendOptions,
  ) : TgStatus {
    assertOwner(caller);
    {
      configured = (getBotToken() != null);
      hasSecret = (getSecretToken() != null);
      hasLlmConfig = (getLlmOpts() != null);
    }
  };

  public func discordStatus(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    getProxySecret : () -> ?Text,
    getLlmOpts : () -> ?SendOptions,
  ) : DiscordStatus {
    assertOwner(caller);
    {
      configured = (getProxySecret() != null);
      hasProxySecret = (getProxySecret() != null);
      hasLlmConfig = (getLlmOpts() != null);
    }
  };

  public func ckethStatus(
    assertOwner : (caller : Principal) -> (),
    caller : Principal,
    getIcpswapQuoteUrl : () -> ?Text,
    getKongswapQuoteUrl : () -> ?Text,
    getIcpswapBroker : () -> ?Text,
    getKongswapBroker : () -> ?Text,
  ) : CkEthStatus {
    assertOwner(caller);
    {
      hasIcpswapQuoteUrl = (getIcpswapQuoteUrl() != null);
      hasKongswapQuoteUrl = (getKongswapQuoteUrl() != null);
      hasIcpswapBroker = (getIcpswapBroker() != null);
      hasKongswapBroker = (getKongswapBroker() != null);
    }
  };

  public func whoami(assertOwner : (caller : Principal) -> (), caller : Principal) : Text {
    assertOwner(caller);
    Principal.toText(caller)
  };

  func normalizeOptText(v : ?Text) : ?Text {
    switch (v) {
      case null null;
      case (?s) {
        let t = Text.trim(s, #char ' ');
        if (Text.size(t) == 0) null else ?t;
      };
    }
  };
}
