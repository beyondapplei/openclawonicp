import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface AgentWallet {
  'principal' : Principal,
  'derivationPathHex' : Array<string>,
  'publicKeyHex' : string,
  'keyName' : string,
  'principalText' : string,
  'chainCodeHex' : string,
}
export type BalanceResult = { 'ok' : bigint } |
  { 'err' : string };
export type BuyCkEthResult = { 'ok' : string } |
  { 'err' : string };
export interface ChatMessage {
  'content' : string,
  'role' : Role,
  'tsNs' : bigint,
}
export interface CkEthStatus {
  'hasIcpswapBroker' : boolean,
  'hasKongswapBroker' : boolean,
  'hasKongswapQuoteUrl' : boolean,
  'hasIcpswapQuoteUrl' : boolean,
}
export interface DiscordStatus {
  'hasLlmConfig' : boolean,
  'hasProxySecret' : boolean,
  'configured' : boolean,
}
export interface EcdsaPublicKeyOut {
  'principal' : Principal,
  'derivationPathHex' : Array<string>,
  'publicKeyHex' : string,
  'keyName' : string,
  'principalText' : string,
  'chainCodeHex' : string,
}
export type EcdsaPublicKeyResult = { 'ok' : EcdsaPublicKeyOut } |
  { 'err' : string };
export type EthAddressResult = { 'ok' : string } |
  { 'err' : string };
export type HeaderField = [string, string];
export type HookAction = {
    'tool' : { 'args' : Array<string>, 'name' : string }
  } |
  { 'reply' : string };
export interface HookEntry {
  'action' : HookAction,
  'trigger' : HookTrigger,
  'name' : string,
  'enabled' : boolean,
}
export type HookTrigger = { 'command' : string } |
  { 'messageContains' : string };
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
export interface LlmTrace {
  'id' : bigint,
  'url' : string,
  'model' : string,
  'provider' : string,
  'tsNs' : bigint,
  'error' : [] | [string],
  'responseBody' : [] | [string],
  'requestBody' : string,
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
export type SendEthResult = { 'ok' : string } |
  { 'err' : string };
export type SendIcpResult = { 'ok' : bigint } |
  { 'err' : string };
export type SendIcrc1Result = { 'ok' : bigint } |
  { 'err' : string };
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
export interface SignWithEcdsaOut {
  'principal' : Principal,
  'messageHashHex' : string,
  'derivationPathHex' : Array<string>,
  'signatureHex' : string,
  'keyName' : string,
  'principalText' : string,
}
export type SignWithEcdsaResult = { 'ok' : SignWithEcdsaOut } |
  { 'err' : string };
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
export type WalletResult = { 'ok' : AgentWallet } |
  { 'err' : string };
export interface _SERVICE {
  'admin_has_provider_api_key' : ActorMethod<[Provider], boolean>,
  'admin_set_cketh_broker' : ActorMethod<[[] | [string]], undefined>,
  'admin_set_cketh_brokers' : ActorMethod<
    [[] | [string], [] | [string]],
    undefined
  >,
  'admin_set_cketh_quote_sources' : ActorMethod<
    [[] | [string], [] | [string]],
    undefined
  >,
  'admin_set_discord' : ActorMethod<[[] | [string]], undefined>,
  'admin_set_llm_opts' : ActorMethod<[SendOptions], undefined>,
  'admin_set_provider_api_key' : ActorMethod<[Provider, string], undefined>,
  'admin_set_tg' : ActorMethod<[string, [] | [string]], undefined>,
  'admin_tg_set_webhook' : ActorMethod<[string], Result>,
  'agent_wallet' : ActorMethod<[], WalletResult>,
  'canister_principal' : ActorMethod<[], Principal>,
  'cketh_status' : ActorMethod<[], CkEthStatus>,
  'dev_llm_traces' : ActorMethod<[bigint, bigint], Array<LlmTrace>>,
  'discord_status' : ActorMethod<[], DiscordStatus>,
  'ecdsa_public_key' : ActorMethod<
    [Array<Uint8Array | number[]>, [] | [string]],
    EcdsaPublicKeyResult
  >,
  'hooks_delete' : ActorMethod<[string], boolean>,
  'hooks_list' : ActorMethod<[], Array<HookEntry>>,
  'hooks_put_command_reply' : ActorMethod<[string, string, string], boolean>,
  'hooks_put_command_tool' : ActorMethod<
    [string, string, string, Array<string>],
    boolean
  >,
  'hooks_put_message_reply' : ActorMethod<[string, string, string], boolean>,
  'hooks_put_message_tool' : ActorMethod<
    [string, string, string, Array<string>],
    boolean
  >,
  'hooks_set_enabled' : ActorMethod<[string, boolean], boolean>,
  'http_request' : ActorMethod<[InHttpRequest], InHttpResponse>,
  'http_request_update' : ActorMethod<[InHttpRequest], InHttpResponse>,
  'http_transform' : ActorMethod<[TransformArgs], HttpResponsePayload>,
  'models_list' : ActorMethod<[Provider, string], ModelsResult>,
  'owner_get' : ActorMethod<[], [] | [Principal]>,
  'sessions_create' : ActorMethod<[string], undefined>,
  'sessions_history' : ActorMethod<[string, bigint], Array<ChatMessage>>,
  'sessions_list' : ActorMethod<[], Array<SessionSummary>>,
  'sessions_list_for' : ActorMethod<[Principal], Array<SessionSummary>>,
  'sessions_reset' : ActorMethod<[string], undefined>,
  'sessions_send' : ActorMethod<[string, string, SendOptions], SendResult>,
  'sign_with_ecdsa' : ActorMethod<
    [Uint8Array | number[], Array<Uint8Array | number[]>, [] | [string]],
    SignWithEcdsaResult
  >,
  'skills_delete' : ActorMethod<[string], boolean>,
  'skills_get' : ActorMethod<[string], [] | [string]>,
  'skills_list' : ActorMethod<[], Array<string>>,
  'skills_put' : ActorMethod<[string, string], undefined>,
  'tg_status' : ActorMethod<[], TgStatus>,
  'tools_invoke' : ActorMethod<[string, Array<string>], ToolResult>,
  'tools_list' : ActorMethod<[], Array<string>>,
  'wallet_balance_erc20' : ActorMethod<
    [string, [] | [string], string],
    BalanceResult
  >,
  'wallet_balance_eth' : ActorMethod<[string, [] | [string]], BalanceResult>,
  'wallet_balance_icp' : ActorMethod<[], BalanceResult>,
  'wallet_balance_icrc1' : ActorMethod<[string], BalanceResult>,
  'wallet_buy_cketh' : ActorMethod<[string, bigint], BuyCkEthResult>,
  'wallet_buy_cketh_one' : ActorMethod<[bigint], BuyCkEthResult>,
  'wallet_buy_erc20_uniswap' : ActorMethod<
    [
      string,
      [] | [string],
      string,
      string,
      string,
      bigint,
      bigint,
      bigint,
      bigint,
      bigint,
    ],
    SendEthResult
  >,
  'wallet_buy_uni' : ActorMethod<
    [string, [] | [string], bigint, bigint, bigint],
    SendEthResult
  >,
  'wallet_eth_address' : ActorMethod<[], EthAddressResult>,
  'wallet_send_erc20' : ActorMethod<
    [string, [] | [string], string, string, bigint],
    SendEthResult
  >,
  'wallet_send_eth' : ActorMethod<
    [string, [] | [string], string, bigint],
    SendEthResult
  >,
  'wallet_send_eth_raw' : ActorMethod<
    [string, [] | [string], string],
    SendEthResult
  >,
  'wallet_send_icp' : ActorMethod<[string, bigint], SendIcpResult>,
  'wallet_send_icrc1' : ActorMethod<
    [string, string, bigint, [] | [bigint]],
    SendIcrc1Result
  >,
  'wallet_token_address' : ActorMethod<[string, string], [] | [string]>,
  'whoami' : ActorMethod<[], string>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
