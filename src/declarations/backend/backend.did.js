export const idlFactory = ({ IDL }) => {
  const HttpHeader = IDL.Record({ 'value' : IDL.Text, 'name' : IDL.Text });
  const HttpResponsePayload = IDL.Record({
    'status' : IDL.Nat,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HttpHeader),
  });
  const TransformArgs = IDL.Record({
    'context' : IDL.Vec(IDL.Nat8),
    'response' : HttpResponsePayload,
  });
  const Provider = IDL.Variant({
    'openai' : IDL.Null,
    'google' : IDL.Null,
    'anthropic' : IDL.Null,
  });
  const ModelsResult = IDL.Variant({
    'ok' : IDL.Vec(IDL.Text),
    'err' : IDL.Text,
  });
  const Role = IDL.Variant({
    'tool' : IDL.Null,
    'user' : IDL.Null,
    'assistant' : IDL.Null,
    'system' : IDL.Null,
  });
  const ChatMessage = IDL.Record({
    'content' : IDL.Text,
    'role' : Role,
    'tsNs' : IDL.Int,
  });
  const SessionSummary = IDL.Record({
    'id' : IDL.Text,
    'updatedAtNs' : IDL.Int,
    'messageCount' : IDL.Nat,
  });
  const SendOptions = IDL.Record({
    'model' : IDL.Text,
    'provider' : Provider,
    'temperature' : IDL.Opt(IDL.Float64),
    'apiKey' : IDL.Text,
    'systemPrompt' : IDL.Opt(IDL.Text),
    'includeHistory' : IDL.Bool,
    'maxTokens' : IDL.Opt(IDL.Nat),
    'skillNames' : IDL.Vec(IDL.Text),
  });
  const SendOk = IDL.Record({
    'raw' : IDL.Opt(IDL.Text),
    'assistant' : ChatMessage,
  });
  const SendResult = IDL.Variant({ 'ok' : SendOk, 'err' : IDL.Text });
  const ToolResult = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  return IDL.Service({
    'http_transform' : IDL.Func(
        [TransformArgs],
        [HttpResponsePayload],
        ['query'],
      ),
    'models_list' : IDL.Func([Provider, IDL.Text], [ModelsResult], []),
    'sessions_create' : IDL.Func([IDL.Text], [], []),
    'sessions_history' : IDL.Func(
        [IDL.Text, IDL.Nat],
        [IDL.Vec(ChatMessage)],
        [],
      ),
    'sessions_list' : IDL.Func([], [IDL.Vec(SessionSummary)], []),
    'sessions_list_for' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(SessionSummary)],
        ['query'],
      ),
    'sessions_reset' : IDL.Func([IDL.Text], [], []),
    'sessions_send' : IDL.Func(
        [IDL.Text, IDL.Text, SendOptions],
        [SendResult],
        [],
      ),
    'skills_delete' : IDL.Func([IDL.Text], [IDL.Bool], []),
    'skills_get' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Text)], []),
    'skills_list' : IDL.Func([], [IDL.Vec(IDL.Text)], []),
    'skills_put' : IDL.Func([IDL.Text, IDL.Text], [], []),
    'tools_invoke' : IDL.Func([IDL.Text, IDL.Vec(IDL.Text)], [ToolResult], []),
    'tools_list' : IDL.Func([], [IDL.Vec(IDL.Text)], []),
  });
};
export const init = ({ IDL }) => { return []; };
