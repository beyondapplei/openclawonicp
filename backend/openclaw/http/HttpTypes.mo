import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";

module {
  public type HttpMethod = { #get; #head; #post; #put; #delete; #patch; #options };
  public type HttpHeader = { name : Text; value : Text };
  public type HttpResponsePayload = { status : Nat; headers : [HttpHeader]; body : Blob };
  public type TransformArgs = { response : HttpResponsePayload; context : Blob };
  public type TransformContext = {
    function : shared query TransformArgs -> async HttpResponsePayload;
    context : Blob;
  };
  public type HttpRequestArgs = {
    url : Text;
    max_response_bytes : ?Nat64;
    method : HttpMethod;
    headers : [HttpHeader];
    body : ?Blob;
    transform : ?TransformContext;
  };
}
