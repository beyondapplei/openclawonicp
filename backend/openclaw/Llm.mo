import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";

import HttpTypes "./HttpTypes";
import Json "./Json";
import Types "./Types";

module {
  public type Http = actor { http_request : HttpTypes.HttpRequestArgs -> async HttpTypes.HttpResponsePayload };

  public func extract(provider : Types.Provider, raw : Text) : ?Text {
    switch (provider) {
      case (#openai) Json.extractStringAfterAny(raw, ["\"content\":\"", "\"content\": \""]);
      case (#anthropic) Json.extractStringAfterAny(raw, ["\"text\":\"", "\"text\": \""]);
      case (#google) Json.extractStringAfterAny(raw, ["\"text\":\"", "\"text\": \""]);
    }
  };

  public func callModel(
    ic : Http,
    transformFn : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    httpCycles : Nat,
    provider : Types.Provider,
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [Types.ChatMessage],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) : async Result.Result<Text, Text> {
    let (url, headers, bodyText) = switch (provider) {
      case (#openai) buildOpenAIRequest(model, apiKey, sysPrompt, history, maxTokens, temperature);
      case (#anthropic) buildAnthropicRequest(model, apiKey, sysPrompt, history, maxTokens, temperature);
      case (#google) buildGoogleRequest(model, apiKey, sysPrompt, history, maxTokens, temperature);
    };

    let req : HttpTypes.HttpRequestArgs = {
      url;
      max_response_bytes = ?(1_000_000 : Nat64);
      method = #post;
      headers;
      body = ?Text.encodeUtf8(bodyText);
      transform = ?{
        function = transformFn;
        context = Blob.fromArray([]);
      };
    };

    let resp = await (with cycles = httpCycles) ic.http_request(req);

    if (resp.status < 200 or resp.status >= 300) {
      let body = switch (Text.decodeUtf8(resp.body)) {
        case null "";
        case (?t) t;
      };
      return #err("http status " # Nat.toText(resp.status) # ": " # body);
    };

    switch (Text.decodeUtf8(resp.body)) {
      case null #err("response body is not valid UTF-8");
      case (?t) #ok(t);
    }
  };

  func buildOpenAIRequest(
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [Types.ChatMessage],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) : (Text, [HttpTypes.HttpHeader], Text) {
    let url = "https://api.openai.com/v1/chat/completions";
    let headers : [HttpTypes.HttpHeader] = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Authorization"; value = "Bearer " # apiKey },
    ];
    let messagesJson = messagesToOpenAIJson(sysPrompt, history);
    let body = "{" #
      "\"model\":\"" # Json.escape(model) # "\"," #
      "\"messages\":" # messagesJson #
      optNatField("max_tokens", maxTokens) #
      optFloatField("temperature", temperature) #
      "}";
    (url, headers, body)
  };

  func buildAnthropicRequest(
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [Types.ChatMessage],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) : (Text, [HttpTypes.HttpHeader], Text) {
    let url = "https://api.anthropic.com/v1/messages";
    let headers : [HttpTypes.HttpHeader] = [
      { name = "Content-Type"; value = "application/json" },
      { name = "x-api-key"; value = apiKey },
      { name = "anthropic-version"; value = "2023-06-01" },
    ];

    let msgJson = messagesToAnthropicJson(history);
    let max = switch (maxTokens) { case null 1024; case (?n) n };
    let body = "{" #
      "\"model\":\"" # Json.escape(model) # "\"," #
      "\"max_tokens\":" # Nat.toText(max) # "," #
      (if (Text.size(sysPrompt) > 0) "\"system\":\"" # Json.escape(sysPrompt) # "\"," else "") #
      "\"messages\":" # msgJson #
      optFloatField("temperature", temperature) #
      "}";
    (url, headers, body)
  };

  func buildGoogleRequest(
    model : Text,
    apiKey : Text,
    sysPrompt : Text,
    history : [Types.ChatMessage],
    maxTokens : ?Nat,
    temperature : ?Float,
  ) : (Text, [HttpTypes.HttpHeader], Text) {
    // Google AI Studio / Gemini (Generative Language API)
    // Endpoint: /v1beta/models/{model}:generateContent?key=...
    let url = "https://generativelanguage.googleapis.com/v1beta/models/" # model # ":generateContent?key=" # apiKey;
    let headers : [HttpTypes.HttpHeader] = [
      { name = "Content-Type"; value = "application/json" },
    ];

    let contentsJson = messagesToGoogleJson(history);
    let genCfg = generationConfigJson(maxTokens, temperature);

    let body = "{" #
      (if (Text.size(sysPrompt) > 0)
        "\"systemInstruction\":{\"parts\":[{\"text\":\"" # Json.escape(sysPrompt) # "\"}]},"
        else "") #
      "\"contents\":" # contentsJson #
      genCfg #
      "}";
    (url, headers, body)
  };

  func optNatField(field : Text, v : ?Nat) : Text {
    switch (v) {
      case null "";
      case (?n) ",\"" # field # "\":" # Nat.toText(n);
    }
  };

  func optFloatField(field : Text, v : ?Float) : Text {
    switch (v) {
      case null "";
      case (?f) ",\"" # field # "\":" # Float.toText(f);
    }
  };

  func generationConfigJson(maxTokens : ?Nat, temperature : ?Float) : Text {
    if (maxTokens == null and temperature == null) return "";
    let maxField = switch (maxTokens) {
      case null "";
      case (?n) "\"maxOutputTokens\":" # Nat.toText(n);
    };
    let tempField = switch (temperature) {
      case null "";
      case (?t) "\"temperature\":" # Float.toText(t);
    };

    let inner =
      if (Text.size(maxField) > 0 and Text.size(tempField) > 0) {
        maxField # "," # tempField
      } else if (Text.size(maxField) > 0) {
        maxField
      } else {
        tempField
      };

    ",\"generationConfig\":{" # inner # "}"
  };

  func messagesToOpenAIJson(sysPrompt : Text, history : [Types.ChatMessage]) : Text {
    var parts = Buffer.Buffer<Text>(history.size() + 1);
    if (Text.size(sysPrompt) > 0) {
      parts.add("{\"role\":\"system\",\"content\":\"" # Json.escape(sysPrompt) # "\"}");
    };
    for (m in history.vals()) {
      let role = switch (m.role) {
        case (#system_) "system";
        case (#assistant) "assistant";
        case (#tool) "tool";
        case (#user) "user";
      };
      parts.add("{\"role\":\"" # role # "\",\"content\":\"" # Json.escape(m.content) # "\"}");
    };
    "[" # Text.join(",", parts.vals()) # "]"
  };

  func messagesToAnthropicJson(history : [Types.ChatMessage]) : Text {
    var parts = Buffer.Buffer<Text>(history.size());
    for (m in history.vals()) {
      switch (m.role) {
        case (#user) {
          parts.add("{\"role\":\"user\",\"content\":\"" # Json.escape(m.content) # "\"}");
        };
        case (#assistant) {
          parts.add("{\"role\":\"assistant\",\"content\":\"" # Json.escape(m.content) # "\"}");
        };
        case (_) {};
      }
    };
    "[" # Text.join(",", parts.vals()) # "]"
  };

  func messagesToGoogleJson(history : [Types.ChatMessage]) : Text {
    // Google uses roles: "user" and "model".
    let parts = Buffer.Buffer<Text>(history.size());
    for (m in history.vals()) {
      switch (m.role) {
        case (#user) {
          parts.add("{\"role\":\"user\",\"parts\":[{\"text\":\"" # Json.escape(m.content) # "\"}]}");
        };
        case (#assistant) {
          parts.add("{\"role\":\"model\",\"parts\":[{\"text\":\"" # Json.escape(m.content) # "\"}]}");
        };
        case (_) {};
      }
    };
    "[" # Text.join(",", parts.vals()) # "]"
  };
}
