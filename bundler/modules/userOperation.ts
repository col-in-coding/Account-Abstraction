/**
 * UserOperation preparation and sending with Custom Paymaster
 */
import { prepareUserOperation, sendUserOperation, getUserOperationHash } from 'viem/account-abstraction'
import { parseUnits, type SignAuthorizationReturnType, type Hex } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { generatePaymasterAndData } from './paymaster'
import { PAYMASTER_ADDRESS, PAYMASTER_VERIFICATION_GAS_LIMIT, PAYMASTER_POST_OP_GAS_LIMIT } from './paymaster'
import { CONTRACTS, env } from './constants'

export interface UserOperationConfig {
    recipient: string
    amount: string
    verificationGasLimit: bigint
}

export interface UserOperationWithSignature {
    calls: Array<{ to: string; value: bigint }>
    account: any
    authorization?: SignAuthorizationReturnType
    verificationGasLimit: bigint
    signature?: string
}

/**
 * Complete workflow: prepare, sign with custom paymaster, and send UserOperation
 */
export async function executeUserOperation(
    client: any,
    config: UserOperationConfig,
    smartAccount: any,
    authorization?: SignAuthorizationReturnType,
) {
    // Step 1: Read real-time nonce for key=0 from EntryPoint
    console.log('📖 Reading nonce from EntryPoint for key=0...')
    const nonce = await client.readContract({
        address: CONTRACTS.ENTRY_POINT_V08 as `0x${string}`,
        abi: [{
            type: 'function',
            name: 'getNonce',
            inputs: [
                { name: 'sender', type: 'address' },
                { name: 'key', type: 'uint192' },
            ],
            outputs: [{ name: 'nonce', type: 'uint256' }],
            stateMutability: 'view',
        }],
        functionName: 'getNonce',
        args: [smartAccount.address as `0x${string}`, 0n], // key=0
    }) as bigint

    console.log('✓ Retrieved nonce from EntryPoint:', nonce)
    console.log('  nonce key:', nonce >> 64n)
    console.log('  nonce sequence:', nonce & ((1n << 64n) - 1n))

    // Step 2: Generate Paymaster signature FIRST (before prepareUserOperation)
    console.log('🔐 Generating custom paymaster signature...')

    const paymasterAccount = privateKeyToAccount((env.PAYMASTER_PRIVATE_KEY) as `0x${string}`)

    const paymasterAndData = await generatePaymasterAndData(
        paymasterAccount,
        CONTRACTS.ENTRY_POINT_V08,
        smartAccount.address,
        nonce,  // Use nonce from EntryPoint
        {
            validUntil: Math.floor(Date.now() / 1000) + 3600,
            validAfter: Math.floor(Date.now() / 1000),
            userType: 0,
            extraData: ("0x" + "00".repeat(32)) as `0x${string}`,
        },
        PAYMASTER_VERIFICATION_GAS_LIMIT,
        PAYMASTER_POST_OP_GAS_LIMIT
    )
    console.log('✓ Paymaster signature generated')
    console.log('  paymasterAndData (packed v0.6 format):', paymasterAndData)
    console.log('  Length:', (paymasterAndData.length - 2) / 2, 'bytes')

    // Step 3: Parse paymasterAndData into v0.8 separate fields
    // Format: paymaster(20) + verificationGasLimit(16) + postOpGasLimit(16) + paymasterData(variable)
    const paymaster = ('0x' + paymasterAndData.slice(2, 42)) as `0x${string}` // 20 bytes
    const paymasterVerificationGasLimit = BigInt('0x' + paymasterAndData.slice(42, 74)) // 16 bytes
    const paymasterPostOpGasLimit = BigInt('0x' + paymasterAndData.slice(74, 106)) // 16 bytes
    const paymasterData = ('0x' + paymasterAndData.slice(106)) as `0x${string}` // rest is paymasterData

    console.log('📦 Parsed Paymaster fields for v0.8:')
    console.log('  paymaster:', paymaster)
    console.log('  paymasterVerificationGasLimit:', paymasterVerificationGasLimit.toString())
    console.log('  paymasterPostOpGasLimit:', paymasterPostOpGasLimit.toString())
    console.log('  paymasterData:', paymasterData)
    console.log('  paymasterData length:', (paymasterData.length - 2) / 2, 'bytes')

    // Step 4: Prepare UserOperation WITH paymaster (for accurate gas estimation)
    const prepared = await prepareUserOperation(client, {
        account: smartAccount,
        authorization,
        calls: [
            {
                to: config.recipient as `0x${string}`,
                value: parseUnits(config.amount, 18),
            },
        ],
        verificationGasLimit: config.verificationGasLimit,
        nonce: nonce,
        // Use v0.8 separate paymaster fields instead of packed paymasterAndData
        paymaster: paymaster,
        paymasterVerificationGasLimit: paymasterVerificationGasLimit,
        paymasterPostOpGasLimit: paymasterPostOpGasLimit,
        paymasterData: paymasterData,
    })

    // Verify the paymaster is correctly attached
    console.log('✓ UserOperation prepared with paymaster')
    console.log('  paymaster address:', (prepared as any).paymaster)
    console.log('  paymasterVerificationGasLimit:', (prepared as any).paymasterVerificationGasLimit?.toString())
    console.log('  paymasterPostOpGasLimit:', (prepared as any).paymasterPostOpGasLimit?.toString())
    console.log('  paymasterData:', (prepared as any).paymasterData)

    // Step 5: Generate UserOperation Hash (for debugging)
    console.log('🔍 Generating UserOperation hash...')
    const chainId = await client.getChainId()
    let userOpHash = getUserOperationHash({
        userOperation: prepared,
        entryPointAddress: CONTRACTS.ENTRY_POINT_V08 as `0x${string}`,
        chainId,
        entryPointVersion: '0.8',
    })
    console.log('📊 [DEBUG] UserOperation Hash:', userOpHash)
    console.log('📊 [DEBUG] Chain ID:', chainId)
    console.log('📊 [DEBUG] Entry Point Address:', CONTRACTS.ENTRY_POINT_V08)

    // Debug: Output intermediate values for comparison with Solidity
    console.log('\n📋 [DEBUG] Intermediate Values:')
    console.log('  initCode:', (prepared as any).initCode)
    console.log('  callData:', prepared.callData)
    console.log('  sender:', prepared.sender)
    console.log('  nonce:', prepared.nonce?.toString())
    console.log('  paymaster:', (prepared as any).paymaster)
    console.log('  paymasterData:', (prepared as any).paymasterData)

    // Step 6: Sign UserOperation
    const signature = await smartAccount.signUserOperation(prepared)
    const signedUserOp = { ...prepared, signature }
    console.log('✓ UserOperation signed with account signature: ', signature)

    // Print all fields for Solidity test
    console.log('\n========== Final UserOperation (for Solidity Test) ==========')
    console.log('sender:', signedUserOp.sender)
    console.log('nonce:', signedUserOp.nonce.toString())
    console.log('initCode:', (signedUserOp as any).initCode)
    console.log('callData:', signedUserOp.callData)
    console.log('callGasLimit:', (signedUserOp as any).callGasLimit?.toString())
    console.log('verificationGasLimit:', (signedUserOp as any).verificationGasLimit?.toString())
    console.log('preVerificationGas:', (signedUserOp as any).preVerificationGas?.toString())
    console.log('maxFeePerGas:', (signedUserOp as any).maxFeePerGas?.toString())
    console.log('maxPriorityFeePerGas:', (signedUserOp as any).maxPriorityFeePerGas?.toString())
    console.log('paymaster:', (signedUserOp as any).paymaster)
    console.log('paymasterVerificationGasLimit:', (signedUserOp as any).paymasterVerificationGasLimit?.toString())
    console.log('paymasterPostOpGasLimit:', (signedUserOp as any).paymasterPostOpGasLimit?.toString())
    console.log('paymasterData:', (signedUserOp as any).paymasterData)
    console.log('signature:', signedUserOp.signature)
    console.log('=========================================================\n')

    // Step 7: Send to Entry Point using viem's native sendUserOperation
    userOpHash = await sendUserOperation(client, signedUserOp)
    console.log('✓ UserOperation sent with hash:', userOpHash)

    return userOpHash
}