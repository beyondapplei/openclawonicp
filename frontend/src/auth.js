import { AuthClient } from '@dfinity/auth-client';
import { createActor, canisterId } from 'declarations/backend';

function identityProviderUrl() {
  if (process.env.DFX_NETWORK === 'ic') {
    return 'https://identity.ic0.app';
  }
  const ii = process.env.CANISTER_ID_INTERNET_IDENTITY;
  if (ii) return `http://${ii}.localhost:4943`;
  return 'http://rdmx6-jaaaa-aaaaa-aaadq-cai.localhost:4943';
}

export async function initAuth() {
  const client = await AuthClient.create();
  const isAuthenticated = await client.isAuthenticated();
  const identity = isAuthenticated ? client.getIdentity() : undefined;
  const actor = canisterId ? createActor(canisterId, identity ? { agentOptions: { identity } } : {}) : undefined;
  const principalText = isAuthenticated ? identity.getPrincipal().toText() : null;
  return { client, actor, isAuthenticated, principalText };
}

export async function loginWithII(client) {
  await new Promise((resolve, reject) => {
    client.login({
      identityProvider: identityProviderUrl(),
      maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1_000_000_000),
      onSuccess: resolve,
      onError: reject,
    });
  });

  const identity = client.getIdentity();
  const actor = createActor(canisterId, { agentOptions: { identity } });
  return {
    actor,
    principalText: identity.getPrincipal().toText(),
  };
}

export async function logoutII(client) {
  await client.logout();
  const actor = canisterId ? createActor(canisterId) : undefined;
  return { actor };
}
