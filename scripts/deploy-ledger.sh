#!/usr/bin/env bash
set -euo pipefail

# 单独部署 ledger（参数内置）
# 如需调整部署参数，直接修改下方变量。

LEDGER_CANISTER="ledger"
DEPLOY_MODE="reinstall"   # 可选: install | reinstall | upgrade

MINTING_ACCOUNT="949f7b6fb6b27944bd230ce528303fb7d72e333a9a8f414be6dc41cd93f177b7"
TOKEN_SYMBOL="LICP"
TOKEN_NAME="Local ICP"
TRANSFER_FEE_E8S="10000"
INITIAL_BALANCE_E8S="100000000000"

LEDGER_ARG="(variant { Init = record {
  send_whitelist = vec {};
  token_symbol = opt \"${TOKEN_SYMBOL}\";
  transfer_fee = opt record { e8s = ${TRANSFER_FEE_E8S} : nat64 };
  minting_account = \"${MINTING_ACCOUNT}\";
  transaction_window = null;
  max_message_size_bytes = null;
  icrc1_minting_account = null;
  archive_options = null;
  initial_values = vec {
    record {
      \"${MINTING_ACCOUNT}\";
      record { e8s = ${INITIAL_BALANCE_E8S} : nat64 }
    }
  };
  token_name = opt \"${TOKEN_NAME}\";
  feature_flags = opt record { icrc2 = true }
} })"

echo "Deploying ${LEDGER_CANISTER} with mode=${DEPLOY_MODE} ..."
dfx deploy "${LEDGER_CANISTER}" --mode "${DEPLOY_MODE}" --argument "${LEDGER_ARG}"

echo "Ledger deploy finished."
