import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Types "./Types";

module {
  public type Skill = {
    name : Text;
    markdown : Text;
    createdAtNs : Int;
    updatedAtNs : Int;
  };

  public type SessionStore = {
    id : Text;
    createdAtNs : Int;
    updatedAtNs : Int;
    messages : [Types.ChatMessage];
  };

  public type UserStore = {
    sessions : [SessionStore];
    skills : [Skill];
    kv : [(Text, Text)];
  };

  public type SessionState = {
    id : Text;
    createdAtNs : Int;
    var updatedAtNs : Int;
    messages : Buffer.Buffer<Types.ChatMessage>;
  };

  public type UserState = {
    sessions : TrieMap.TrieMap<Text, SessionState>;
    skills : TrieMap.TrieMap<Text, Skill>;
    kv : TrieMap.TrieMap<Text, Text>;
  };

  public func initUsers() : TrieMap.TrieMap<Principal, UserState> {
    TrieMap.TrieMap<Principal, UserState>(Principal.equal, Principal.hash)
  };

  public func getOrInitUser(users : TrieMap.TrieMap<Principal, UserState>, caller : Principal) : UserState {
    switch (users.get(caller)) {
      case (?u) u;
      case null {
        let u : UserState = {
          sessions = TrieMap.TrieMap<Text, SessionState>(Text.equal, Text.hash);
          skills = TrieMap.TrieMap<Text, Skill>(Text.equal, Text.hash);
          kv = TrieMap.TrieMap<Text, Text>(Text.equal, Text.hash);
        };
        users.put(caller, u);
        u
      };
    }
  };

  public func getOrInitSession(u : UserState, sessionId : Text, nowNs : () -> Int) : SessionState {
    switch (u.sessions.get(sessionId)) {
      case (?s) s;
      case null {
        let ts = nowNs();
        let s : SessionState = {
          id = sessionId;
          createdAtNs = ts;
          var updatedAtNs = ts;
          messages = Buffer.Buffer<Types.ChatMessage>(0);
        };
        u.sessions.put(sessionId, s);
        s
      };
    }
  };

  public func toStore(users : TrieMap.TrieMap<Principal, UserState>) : [(Principal, UserStore)] {
    let out = Buffer.Buffer<(Principal, UserStore)>(users.size());
    for ((p, u) in users.entries()) {
      let sessionsBuf = Buffer.Buffer<SessionStore>(u.sessions.size());
      for ((_, s) in u.sessions.entries()) {
        sessionsBuf.add({
          id = s.id;
          createdAtNs = s.createdAtNs;
          updatedAtNs = s.updatedAtNs;
          messages = Buffer.toArray(s.messages);
        });
      };

      let skillsBuf = Buffer.Buffer<Skill>(u.skills.size());
      for ((_, sk) in u.skills.entries()) { skillsBuf.add(sk) };

      let kvBuf = Buffer.Buffer<(Text, Text)>(u.kv.size());
      for ((k, v) in u.kv.entries()) { kvBuf.add((k, v)) };

      out.add((p, {
        sessions = Buffer.toArray(sessionsBuf);
        skills = Buffer.toArray(skillsBuf);
        kv = Buffer.toArray(kvBuf);
      }));
    };
    Buffer.toArray(out)
  };

  public func fromStore(usersStore : [(Principal, UserStore)]) : TrieMap.TrieMap<Principal, UserState> {
    let users = initUsers();
    for ((p, us) in usersStore.vals()) {
      let u : UserState = {
        sessions = TrieMap.TrieMap<Text, SessionState>(Text.equal, Text.hash);
        skills = TrieMap.TrieMap<Text, Skill>(Text.equal, Text.hash);
        kv = TrieMap.TrieMap<Text, Text>(Text.equal, Text.hash);
      };

      for (s in us.sessions.vals()) {
        let ss : SessionState = {
          id = s.id;
          createdAtNs = s.createdAtNs;
          var updatedAtNs = s.updatedAtNs;
          messages = Buffer.fromArray<Types.ChatMessage>(s.messages);
        };
        u.sessions.put(s.id, ss);
      };

      for (sk in us.skills.vals()) { u.skills.put(sk.name, sk) };
      for ((k, v) in us.kv.vals()) { u.kv.put(k, v) };

      users.put(p, u);
    };
    users
  };
}
