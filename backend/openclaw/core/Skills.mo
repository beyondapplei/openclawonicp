import Buffer "mo:base/Buffer";
import Text "mo:base/Text";

import Store "./Store";

module {
  public func put(u : Store.UserState, name : Text, markdown : Text, nowNs : () -> Int) {
    let ts = nowNs();
    let trimmed = Text.trim(name, #char ' ');
    if (Text.size(trimmed) == 0) return;
    switch (u.skills.get(trimmed)) {
      case null {
        u.skills.put(trimmed, { name = trimmed; markdown; createdAtNs = ts; updatedAtNs = ts });
      };
      case (?sk) {
        u.skills.put(trimmed, { name = trimmed; markdown; createdAtNs = sk.createdAtNs; updatedAtNs = ts });
      };
    }
  };

  public func get(u : Store.UserState, name : Text) : ?Text {
    switch (u.skills.get(name)) {
      case null null;
      case (?sk) ?sk.markdown;
    }
  };

  public func list(u : Store.UserState) : [Text] {
    let buf = Buffer.Buffer<Text>(u.skills.size());
    for ((name, _) in u.skills.entries()) { buf.add(name) };
    Buffer.toArray(buf)
  };

  public func delete(u : Store.UserState, name : Text) : Bool {
    switch (u.skills.remove(name)) {
      case null false;
      case (?_) true;
    }
  };

  public func buildSystemPrompt(u : Store.UserState, basePrompt : ?Text, skillNames : [Text]) : Text {
    let buf = Buffer.Buffer<Text>(2 + skillNames.size());
    switch (basePrompt) {
      case null {};
      case (?p) {
        if (Text.size(Text.trim(p, #char ' ')) > 0) buf.add(p);
      };
    };

    for (name in skillNames.vals()) {
      switch (u.skills.get(name)) {
        case null {};
        case (?sk) {
          buf.add("\n\n# Skill: " # sk.name # "\n" # sk.markdown);
        };
      }
    };

    Text.join("", buf.vals())
  };
}
