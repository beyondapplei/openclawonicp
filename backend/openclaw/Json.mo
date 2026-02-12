import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";

module {
  public func escape(t : Text) : Text {
    let out = Buffer.Buffer<Text>(Text.size(t));
    for (c in t.chars()) {
      switch (c) {
        case ('\\') out.add("\\\\");
        case ('\"') out.add("\\\"");
        case ('\n') out.add("\\n");
        case ('\r') out.add("\\r");
        case ('\t') out.add("\\t");
        case _ out.add(Text.fromChar(c));
      }
    };
    Text.join("", out.vals())
  };

  // Extract the JSON string value right after a needle like "\"content\":\"".
  public func extractStringAfter(raw : Text, needle : Text) : ?Text {
    let it = Text.split(raw, #text needle);
    ignore it.next();
    switch (it.next()) {
      case null null;
      case (?after) readJsonStringFromText(after);
    }
  };

  public func extractStringAfterAny(raw : Text, needles : [Text]) : ?Text {
    for (n in needles.vals()) {
      switch (extractStringAfter(raw, n)) {
        case null {};
        case (?v) { return ?v };
      }
    };
    null
  };

  func readJsonStringFromText(after : Text) : ?Text {
    let pieces = Buffer.Buffer<Text>(16);
    let cs = after.chars();
    let chQuote = Char.fromNat32(34);
    let chBackslash = Char.fromNat32(92);
    var escaping = false;
    var unicodeLeft : Nat = 0;
    var unicodeAcc : Nat32 = 0;

    label read loop {
      switch (cs.next()) {
        case null return null;
        case (?c) {
          if (unicodeLeft > 0) {
            let v = hexValChar(c);
            switch (v) {
              case null return null;
              case (?n) {
                unicodeAcc := unicodeAcc * 16 + Nat32.fromNat(n);
                unicodeLeft -= 1;
                if (unicodeLeft == 0) {
                  pieces.add(Text.fromChar(Char.fromNat32(unicodeAcc)));
                };
              };
            };
            continue read;
          };

          if (escaping) {
            escaping := false;
            if (c == chQuote) {
              pieces.add(Text.fromChar(chQuote));
            } else if (c == chBackslash) {
              pieces.add(Text.fromChar(chBackslash));
            } else if (c == 'n') {
              pieces.add("\n");
            } else if (c == 'r') {
              pieces.add("\r");
            } else if (c == 't') {
              pieces.add("\t");
            } else if (c == 'u') {
              unicodeLeft := 4;
              unicodeAcc := 0;
            } else {
              return null;
            };
            continue read;
          };

          if (c == chQuote) {
            return ?Text.join("", pieces.vals());
          } else if (c == chBackslash) {
            escaping := true;
          } else {
            pieces.add(Text.fromChar(c));
          };
        };
      }
    };
    null
  };

  func hexValChar(c : Char) : ?Nat {
    let n = Char.toNat32(c);
    if (n >= 48 and n <= 57) return ?Nat32.toNat(n - 48);
    if (n >= 65 and n <= 70) return ?Nat32.toNat(n - 55);
    if (n >= 97 and n <= 102) return ?Nat32.toNat(n - 87);
    null
  };
}
