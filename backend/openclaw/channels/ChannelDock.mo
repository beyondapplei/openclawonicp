module {
  public type ChannelDock = {
    id : Text;
    webhookPrefix : Text;
    sessionPrefix : Text;
  };

  public let telegram : ChannelDock = {
    id = "telegram";
    webhookPrefix = "/tg/webhook";
    sessionPrefix = "tg:";
  };

  public let discord : ChannelDock = {
    id = "discord";
    webhookPrefix = "/discord/webhook";
    sessionPrefix = "dc:";
  };

  public let docks : [ChannelDock] = [
    telegram,
    discord,
  ];

  public func sessionIdFor(dock : ChannelDock, channelId : Text) : Text {
    dock.sessionPrefix # channelId
  };
}
