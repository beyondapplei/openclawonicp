import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Result "mo:base/Result";
import Text "mo:base/Text";

import HttpTypes "../http/HttpTypes";
import Json "../http/Json";
import Llm "../llm/Llm";

module {
  public type ResearchResult = Result.Result<Text, Text>;

  public func research(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    topic : Text,
    marketLimit : Nat,
    newsLimit : Nat,
  ) : async ResearchResult {
    let q = Text.trim(topic, #char ' ');
    if (Text.size(q) == 0) return #err("topic is required");

    let mLimit = clampLimit(marketLimit, 8);
    let nLimit = clampLimit(newsLimit, 8);

    var pmItemsJson = "[]";
    var pmError : ?Text = null;
    let pmUrl = "https://gamma-api.polymarket.com/public-search?q=" # urlEncode(q) # "&limit_per_type=" # Nat.toText(mLimit);
    switch (await fetchPolymarketCandidates(ic, transform, httpCycles, pmUrl, mLimit)) {
      case (#ok(items)) { pmItemsJson := items };
      case (#err(e)) { pmError := ?e };
    };

    var newsItemsJson = "[]";
    var newsError : ?Text = null;
    let newsUrl = "https://news.google.com/rss/search?q=" # urlEncode(q) # "&hl=en-US&gl=US&ceid=US:en";
    switch (await fetchNewsHeadlines(ic, transform, httpCycles, newsUrl, nLimit)) {
      case (#ok(items)) { newsItemsJson := items };
      case (#err(e)) { newsError := ?e };
    };

    if (pmError != null and newsError != null) {
      return #err(
        "both sources failed; polymarket=" # optionText(pmError) #
        "; news=" # optionText(newsError),
      );
    };

    let pmErrorField = optionJsonString(pmError);
    let newsErrorField = optionJsonString(newsError);
    #ok(
      "{" #
      "\"query\":\"" # Json.escape(q) # "\"," #
      "\"sources\":{" #
      "\"polymarket_url\":\"" # Json.escape(pmUrl) # "\"," #
      "\"news_url\":\"" # Json.escape(newsUrl) # "\"" #
      "}," #
      "\"polymarket_candidates\":" # pmItemsJson # "," #
      "\"news_headlines\":" # newsItemsJson # "," #
      "\"polymarket_error\":" # pmErrorField # "," #
      "\"news_error\":" # newsErrorField #
      "}",
    )
  };

  func fetchPolymarketCandidates(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    url : Text,
    limit : Nat,
  ) : async Result.Result<Text, Text> {
    let raw = switch (await httpGetUtf8(ic, transform, httpCycles, url)) {
      case (#ok(v)) v;
      case (#err(e)) return #err("polymarket fetch failed: " # e);
    };

    let questions = Json.extractAllStringsAfterAny(raw, ["\"question\":\"", "\"title\":\"", "\"name\":\""]);
    let slugs = Json.extractAllStringsAfter(raw, "\"slug\":\"");
    if (questions.size() == 0) return #err("no polymarket candidates parsed");

    let out = Buffer.Buffer<Text>(limit);
    var i : Nat = 0;
    let maxN = if (questions.size() < limit) questions.size() else limit;
    while (i < maxN) {
      let q = questions[i];
      let slug = if (i < slugs.size()) slugs[i] else "";
      out.add(
        "{" #
        "\"question\":\"" # Json.escape(q) # "\"," #
        "\"slug\":\"" # Json.escape(slug) # "\"" #
        "}",
      );
      i += 1;
    };
    #ok("[" # Text.join(",", out.vals()) # "]")
  };

  func fetchNewsHeadlines(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    url : Text,
    limit : Nat,
  ) : async Result.Result<Text, Text> {
    let raw = switch (await httpGetUtf8(ic, transform, httpCycles, url)) {
      case (#ok(v)) v;
      case (#err(e)) return #err("news fetch failed: " # e);
    };

    let titlesAll = extractXmlTagValues(raw, "title");
    let linksAll = extractXmlTagValues(raw, "link");
    let datesAll = extractXmlTagValues(raw, "pubDate");
    if (titlesAll.size() <= 1) return #err("no news headlines parsed");

    let out = Buffer.Buffer<Text>(limit);
    var i : Nat = 1; // RSS channel title is first entry
    var emitted : Nat = 0;
    while (i < titlesAll.size() and emitted < limit) {
      let title = titlesAll[i];
      let link = if (i < linksAll.size()) linksAll[i] else "";
      let pubDate = if (i - 1 < datesAll.size()) datesAll[i - 1] else "";
      out.add(
        "{" #
        "\"title\":\"" # Json.escape(htmlDecode(title)) # "\"," #
        "\"link\":\"" # Json.escape(link) # "\"," #
        "\"pub_date\":\"" # Json.escape(pubDate) # "\"" #
        "}",
      );
      i += 1;
      emitted += 1;
    };
    #ok("[" # Text.join(",", out.vals()) # "]")
  };

  func httpGetUtf8(
    ic : Llm.Http,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    url : Text,
  ) : async Result.Result<Text, Text> {
    let req : HttpTypes.HttpRequestArgs = {
      url;
      max_response_bytes = ?(500_000 : Nat64);
      method = #get;
      headers = [];
      body = null;
      transform = ?{
        function = transform;
        context = Blob.fromArray([]);
      };
    };
    let resp = await (with cycles = httpCycles) ic.http_request(req);
    let payload = switch (Text.decodeUtf8(resp.body)) {
      case null return #err("response is not utf-8");
      case (?t) t;
    };
    if (resp.status < 200 or resp.status >= 300) {
      return #err("http status " # Nat.toText(resp.status) # ": " # payload);
    };
    #ok(payload)
  };

  func extractXmlTagValues(raw : Text, tag : Text) : [Text] {
    let openTag = "<" # tag # ">";
    let closeTag = "</" # tag # ">";
    let out = Buffer.Buffer<Text>(8);
    let it = Text.split(raw, #text openTag);
    ignore it.next();
    loop {
      switch (it.next()) {
        case null return Buffer.toArray(out);
        case (?afterOpen) {
          let endIt = Text.split(afterOpen, #text closeTag);
          switch (endIt.next()) {
            case null {};
            case (?value) out.add(Text.trim(value, #char ' '));
          }
        };
      }
    }
  };

  func htmlDecode(input : Text) : Text {
    let s1 = replaceAll(input, "&amp;", "&");
    let s2 = replaceAll(s1, "&lt;", "<");
    let s3 = replaceAll(s2, "&gt;", ">");
    let s4 = replaceAll(s3, "&quot;", "\"");
    replaceAll(s4, "&#39;", "'")
  };

  func replaceAll(text : Text, token : Text, value : Text) : Text {
    Text.join(value, Text.split(text, #text token))
  };

  func optionText(v : ?Text) : Text {
    switch (v) {
      case null "";
      case (?s) s;
    }
  };

  func optionJsonString(v : ?Text) : Text {
    switch (v) {
      case null "null";
      case (?s) "\"" # Json.escape(s) # "\"";
    }
  };

  func clampLimit(v : Nat, fallback : Nat) : Nat {
    let x = if (v == 0) fallback else v;
    if (x > 20) 20 else x
  };

  func urlEncode(input : Text) : Text {
    let bytes = Blob.toArray(Text.encodeUtf8(input));
    let out = Buffer.Buffer<Text>(bytes.size());
    for (b in bytes.vals()) {
      if (isUnreserved(b)) {
        out.add(Text.fromChar(Char.fromNat32(Nat32.fromNat(Nat8.toNat(b)))));
      } else {
        out.add("%" # hex2(b));
      }
    };
    Text.join("", out.vals())
  };

  func isUnreserved(b : Nat8) : Bool {
    let n = Nat8.toNat(b);
    // A-Z a-z 0-9 - _ . ~
    (n >= 48 and n <= 57) or
    (n >= 65 and n <= 90) or
    (n >= 97 and n <= 122) or
    n == 45 or n == 95 or n == 46 or n == 126
  };

  func hex2(b : Nat8) : Text {
    let table = [
      "0",
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
    ];
    let n = Nat8.toNat(b);
    let hi = n / 16;
    let lo = n % 16;
    table[hi] # table[lo]
  };
}
