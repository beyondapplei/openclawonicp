import Buffer "mo:base/Buffer";
import Text "mo:base/Text";

module {
  public type ToolProfile = { #minimal; #messaging; #wallet; #full };

  public type ToolFilter = {
    profile : ?ToolProfile;
    allow : [Text];
    deny : [Text];
  };

  // Names are normalized to lowercase to keep matching case-insensitive.
  let groupCore : [Text] = ["kv.get", "kv.put", "time.nowns"];
  let groupMessaging : [Text] = ["tg_send_message"];
  let groupWallet : [Text] = [
    "wallet_send_icp",
    "wallet_send_eth",
    "wallet_send_erc20",
    "wallet_buy_erc20_uniswap",
    "wallet_swap_uniswap",
    "wallet_buy_uni",
    "polymarket_research",
    "wallet_buy_cketh",
  ];

  public func isAllowed(toolName : Text, filter : ?ToolFilter) : Bool {
    switch (filter) {
      case null true;
      case (?f) {
        let name = normalize(toolName);
        let denyNames = expand(f.deny);
        if (contains(denyNames, name)) return false;

        switch (f.profile) {
          case null {};
          case (?#full) {};
          case (?profile) {
            let profileNames = profileToolNames(profile);
            if (not contains(profileNames, name)) return false;
          };
        };

        let allowNames = expand(f.allow);
        if (allowNames.size() == 0) return true;
        contains(allowNames, name)
      };
    }
  };

  public func expand(names : [Text]) : [Text] {
    let out = Buffer.Buffer<Text>(names.size());
    for (raw in names.vals()) {
      let name = normalize(raw);
      if (Text.size(name) == 0) {
        // Skip empty names.
      } else if (name == "group:core" or name == "group:kv" or name == "group:time") {
        addManyUnique(out, groupCore);
      } else if (name == "group:messaging") {
        addManyUnique(out, groupMessaging);
      } else if (name == "group:wallet") {
        addManyUnique(out, groupWallet);
      } else if (name == "group:all") {
        addManyUnique(out, groupCore);
        addManyUnique(out, groupMessaging);
        addManyUnique(out, groupWallet);
      } else {
        addUnique(out, name);
      };
    };
    Buffer.toArray(out)
  };

  func profileToolNames(profile : ToolProfile) : [Text] {
    switch (profile) {
      case (#minimal) groupCore;
      case (#messaging) mergeUnique([groupCore, groupMessaging]);
      case (#wallet) mergeUnique([groupCore, groupWallet]);
      case (#full) [];
    }
  };

  func mergeUnique(groups : [[Text]]) : [Text] {
    let out = Buffer.Buffer<Text>(0);
    for (group in groups.vals()) {
      addManyUnique(out, group);
    };
    Buffer.toArray(out)
  };

  func addManyUnique(out : Buffer.Buffer<Text>, values : [Text]) {
    for (v in values.vals()) {
      addUnique(out, v);
    };
  };

  func addUnique(out : Buffer.Buffer<Text>, raw : Text) {
    let value = normalize(raw);
    if (Text.size(value) == 0) return;
    if (not containsBuffer(out, value)) {
      out.add(value);
    };
  };

  func contains(names : [Text], value : Text) : Bool {
    let target = normalize(value);
    for (name in names.vals()) {
      if (normalize(name) == target) return true;
    };
    false
  };

  func containsBuffer(buf : Buffer.Buffer<Text>, value : Text) : Bool {
    let target = normalize(value);
    var i : Nat = 0;
    let n = buf.size();
    while (i < n) {
      if (normalize(buf.get(i)) == target) return true;
      i += 1;
    };
    false
  };

  func normalize(v : Text) : Text {
    Text.toLowercase(Text.trim(v, #char ' '))
  };
}
