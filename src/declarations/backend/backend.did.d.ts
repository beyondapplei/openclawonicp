import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface ChatMessage {
  'content' : string,
  'role' : Role,
  'tsNs' : bigint,
}
export type HeaderField = [string, string];
export interface HttpHeader { 'value' : string, 'name' : string }
export interface HttpResponsePayload {
  'status' : bigint,
  'body' : Uint8Array | number[],
  'headers' : Array<HttpHeader>,
}
export interface InHttpRequest {
  'url' : string,
  'method' : string,
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
}
export interface InHttpResponse {
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
  'upgrade' : [] | [boolean],
  'streaming_strategy' : [] | [
    {
        'Callback' : {
          'token' : Uint8Array | number[],
          'callback' : [Principal, string],
        }
      }
  ],
  'status_code' : number,
}
export type ModelsResult = { 'ok' : Array<string> } |
  { 'err' : string };
export type Provider = { 'openai' : null } |
  { 'google' : null } |
  { 'anthropic' : null };
export type Result = { 'ok' : string } |
  { 'err' : string };
export type Role = { 'tool' : null } |
  { 'user' : null } |
  { 'assistant' : null } |
  { 'system' : null };
export interface SendOk { 'raw' : [] | [string], 'assistant' : ChatMessage }
export interface SendOptions {
  'model' : string,
  'provider' : Provider,
  'temperature' : [] | [number],
  'apiKey' : string,
  'systemPrompt' : [] | [string],
  'includeHistory' : boolean,
  'maxTokens' : [] | [bigint],
  'skillNames' : Array<string>,
}
export type SendResult = { 'ok' : SendOk } |
  { 'err' : string };
export interface SessionSummary {
  'id' : string,
  'updatedAtNs' : bigint,
  'messageCount' : bigint,
}
export interface TgStatus {
  'hasLlmConfig' : boolean,
  'configured' : boolean,
  'hasSecret' : boolean,
}
export type ToolResult = { 'ok' : string } |
  { 'err' : string };
export interface TransformArgs {
  'context' : Uint8Array | number[],
  'response' : HttpResponsePayload,
}
export interface _SERVICE {
  'admin_set_llm_opts' : ActorMethod<[SendOptions], undefined>,
  'admin_set_tg' : ActorMethod<[string, [] | [string]], undefined>,
  'admin_tg_set_webhook' : ActorMethod<[string], Result>,
  'http_request' : ActorMethod<[InHttpRequest], InHttpResponse>,
  'http_request_update' : ActorMethod<[InHttpRequest], InHttpResponse>,
  'http_transform' : ActorMethod<[TransformArgs], HttpResponsePayload>,
  'models_list' : ActorMethod<[Provider, string], ModelsResult>,
  'sessions_create' : ActorMethod<[string], undefined>,
  'sessions_history' : ActorMethod<[string, bigint], Array<ChatMessage>>,
  'sessions_list' : ActorMethod<[], Array<SessionSummary>>,
  'sessions_list_for' : ActorMethod<[Principal], Array<SessionSummary>>,
  'sessions_reset' : ActorMethod<[string], undefined>,
  'sessions_send' : ActorMethod<[string, string, SendOptions], SendResult>,
  'skills_delete' : ActorMethod<[string], boolean>,
  'skills_get' : ActorMethod<[string], [] | [string]>,
  'skills_list' : ActorMethod<[], Array<string>>,
  'skills_put' : ActorMethod<[string, string], undefined>,
  'tg_status' : ActorMethod<[], TgStatus>,
  'tools_invoke' : ActorMethod<[string, Array<string>], ToolResult>,
  'tools_list' : ActorMethod<[], Array<string>>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
