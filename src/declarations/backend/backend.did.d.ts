import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface ChatMessage {
  'content' : string,
  'role' : Role,
  'tsNs' : bigint,
}
export interface HttpHeader { 'value' : string, 'name' : string }
export interface HttpResponsePayload {
  'status' : bigint,
  'body' : Uint8Array | number[],
  'headers' : Array<HttpHeader>,
}
export type Provider = { 'openai' : null } |
  { 'google' : null } |
  { 'anthropic' : null };
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
export type ToolResult = { 'ok' : string } |
  { 'err' : string };
export interface TransformArgs {
  'context' : Uint8Array | number[],
  'response' : HttpResponsePayload,
}
export interface _SERVICE {
  'http_transform' : ActorMethod<[TransformArgs], HttpResponsePayload>,
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
  'tools_invoke' : ActorMethod<[string, Array<string>], ToolResult>,
  'tools_list' : ActorMethod<[], Array<string>>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
