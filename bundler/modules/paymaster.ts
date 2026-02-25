import {
  type PublicClient,
  type WalletClient,
  toHex,
  keccak256,
  encodePacked,
  type Address,
  getAddress
} from 'viem';

import { CONTRACTS } from './constants';

export interface PaymasterDataInput {
  validUntil: number;      // uint48 - signature valid until timestamp
  validAfter: number;      // uint48 - signature valid after timestamp
  userType: number;        // uint8 - user type indicator
  extraData: `0x${string}`; // bytes32 - extra data
}

// ============================================================================
// OPTION 1: Use Third-party Paymaster (Etherspot)
// ============================================================================
// export const paymasterClient = createPaymasterClient({
//     transport: http(BUNDLER_URL)
// });
// export const paymasterContext = { policyId: "" } // add your policy id here

// ============================================================================
// OPTION 2: Use Your Own Custom Paymaster
// ============================================================================
export const PAYMASTER_VERIFICATION_GAS_LIMIT = 50000n;
export const PAYMASTER_POST_OP_GAS_LIMIT = 50000n;

// NOTE: Custom Paymaster with signature verification
// paymasterData format: validUntil(6) + validAfter(6) + userType(1) + extraData(32) + signature(65)
export const paymasterContext = {
  validUntil: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now (uint48)
  validAfter: Math.floor(Date.now() / 1000), // current timestamp (uint48)
  userType: 0, // user type indicator (uint8)
  extraData: "0x" + "00".repeat(32), // 32 bytes of extra data
  // signature: will be added after signing (65 bytes)
}

/**
 * Generate signature for custom paymaster
 *
 * Signature data hash = keccak256(abi.encodePacked(
 *   address(entryPoint),
 *   address(this), // paymaster
 *   userOp.sender,
 *   userOp.nonce,
 *   validUntil,
 *   validAfter,
 *   paymasterData (without signature)
 * ))
 */

/**
 * Encode paymaster data according to contract spec:
 * validUntil(6) + validAfter(6) + userType(1) + extraData(32) = 45 bytes
 */
export function encodePaymasterData(data: PaymasterDataInput): `0x${string}` {
  // Convert numbers to bytes
  const validUntilHex = toHex(data.validUntil, { size: 6 });
  const validAfterHex = toHex(data.validAfter, { size: 6 });
  const userTypeHex = toHex(data.userType, { size: 1 });
  const extraDataHex = data.extraData;

  // Concatenate: 6 + 6 + 1 + 32 = 45 bytes
  return `${validUntilHex}${validAfterHex.slice(2)}${userTypeHex.slice(2)}${extraDataHex.slice(2)}` as `0x${string}`;
}

/**
 * Build complete paymasterAndData according to contract spec:
 * paymaster(20) + verificationGasLimit(16) + postOpGasLimit(16) + paymasterData(45 + 65 signature)
 */
export function buildPaymasterAndData(
  paymasterData: PaymasterDataInput,
  signature: string,
  verificationGasLimit: bigint = 50000n,
  postOpGasLimit: bigint = 50000n
): `0x${string}` {
  const paymasterDataEncoded = encodePaymasterData(paymasterData);

  // Format: paymaster(20) + verificationGasLimit(16) + postOpGasLimit(16) + paymasterData + signature
  // Each gas limit is uint128 (16 bytes = 32 hex chars)
  return `${CONTRACTS.PAYMASTER}${verificationGasLimit.toString(16).padStart(32, '0')}${postOpGasLimit.toString(16).padStart(32, '0')}${paymasterDataEncoded.slice(2)}${signature.slice(2)}` as `0x${string}`;
}

export async function generatePaymasterAndData(
  paymasterAccount: any,
  entryPointAddress: Address,
  userAddress: Address,
  userNonce: bigint,
  paymasterDataInput: PaymasterDataInput,
  verificationGasLimit: bigint = 50000n,
  postOpGasLimit: bigint = 50000n
): Promise<`0x${string}`> {

  const paymasterDataEncoded = encodePaymasterData(paymasterDataInput);
  console.log("Encoded Paymaster Data (without signature):", paymasterDataEncoded);

  const dataHash = keccak256(
    encodePacked(
      ['address', 'address', 'address', 'uint256', 'uint48', 'uint48', 'bytes'],
      [
        entryPointAddress,
        CONTRACTS.PAYMASTER,
        userAddress,
        userNonce,
        paymasterDataInput.validUntil,
        paymasterDataInput.validAfter,
        paymasterDataEncoded,
      ]
    )
  );

  console.log("Debug - Data Hash:", dataHash);
  console.log("Debug - EntryPoint:", entryPointAddress);
  console.log("Debug - Paymaster:", CONTRACTS.PAYMASTER);
  console.log("Debug - User Address:", userAddress);
  console.log("Debug - User Nonce:", userNonce.toString());
  console.log("Debug - Valid Until:", paymasterDataInput.validUntil);
  console.log("Debug - Valid After:", paymasterDataInput.validAfter);
  console.log("Debug - Paymaster Data Encoded:", paymasterDataEncoded);

  // ✅ FIX: signMessage already adds Ethereum prefix, so sign the raw dataHash
  // viem's signMessage will automatically add "\x19Ethereum Signed Message:\n32" prefix
  const signature = await paymasterAccount.signMessage({
    message: { raw: dataHash }, // Sign the raw dataHash, viem adds prefix automatically
  });

  console.log("Generated Signature:", signature);
  return buildPaymasterAndData(
    paymasterDataInput,
    signature,
    verificationGasLimit,
    postOpGasLimit
  );
}