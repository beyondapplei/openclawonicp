import Blob "mo:base/Blob";
import Nat16 "mo:base/Nat16";
import Text "mo:base/Text";

module {
  public type HeaderField = (Text, Text);
  public type InHttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };
  public type InHttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
    streaming_strategy : ?{
      #Callback : {
        callback : shared query () -> async ();
        token : Blob;
      }
    };
    upgrade : ?Bool;
  };

  public type QueryHandler = {
    canHandleQuery : (req : InHttpRequest) -> Bool;
    queryResponse : () -> InHttpResponse;
  };

  public type UpdateHandler = {
    canHandleUpdate : (req : InHttpRequest) -> Bool;
    handleUpdate : (req : InHttpRequest) -> async InHttpResponse;
  };

  public func routeQuery(req : InHttpRequest, handlers : [QueryHandler]) : InHttpResponse {
    for (h in handlers.vals()) {
      if (h.canHandleQuery(req)) return h.queryResponse();
    };
    {
      status_code = 404;
      headers = [("content-type", "text/plain")];
      body = Text.encodeUtf8("not found");
      streaming_strategy = null;
      upgrade = null;
    }
  };

  public func routeUpdate(req : InHttpRequest, handlers : [UpdateHandler]) : async InHttpResponse {
    for (h in handlers.vals()) {
      if (h.canHandleUpdate(req)) return await h.handleUpdate(req);
    };
    {
      status_code = 404;
      headers = [("content-type", "text/plain")];
      body = Text.encodeUtf8("not found");
      streaming_strategy = null;
      upgrade = null;
    }
  };
}
