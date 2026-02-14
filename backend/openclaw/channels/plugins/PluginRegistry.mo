import ChannelRouter "../ChannelRouter";
import DiscordChannelAdapter "../DiscordChannelAdapter";
import TelegramChannelAdapter "../TelegramChannelAdapter";

module {
  public type Deps = {
    telegram : TelegramChannelAdapter.Deps;
    discord : DiscordChannelAdapter.Deps;
  };

  public func queryHandlers() : [ChannelRouter.QueryHandler] {
    [
      TelegramChannelAdapter.queryHandler(),
      DiscordChannelAdapter.queryHandler(),
    ]
  };

  public func updateHandlers(deps : Deps) : [ChannelRouter.UpdateHandler] {
    [
      TelegramChannelAdapter.updateHandler(deps.telegram),
      DiscordChannelAdapter.updateHandler(deps.discord),
    ]
  };
}
