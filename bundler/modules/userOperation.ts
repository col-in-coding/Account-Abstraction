/**
 * UserOperation preparation and sending
 */
import { prepareUserOperation, sendUserOperation } from 'viem/account-abstraction'
import { parseUnits, type SignAuthorizationReturnType } from 'viem'
import type { PublicClient } from 'viem'

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
 * Prepare a UserOperation with gas estimates
 */
export async function prepareUserOp(
    client: any,
    config: UserOperationConfig,
    smartAccount: any,
    authorization?: SignAuthorizationReturnType
) {
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
    })

    console.log('UserOperation prepared successfully')
    return prepared
}

/**
 * Sign a prepared UserOperation
 */
export async function signUserOp(smartAccount: any, prepared: any) {
    const signature = await smartAccount.signUserOperation(prepared)
    const signedUserOp = { ...prepared, signature }

    console.log('UserOperation signed successfully')
    return signedUserOp
}

/**
 * Send a signed UserOperation to the bundler
 */
export async function sendUserOp(client: any, signedUserOp: any) {
    console.log('Sending UserOperation to bundler...')
    const userOpHash = await sendUserOperation(client, signedUserOp)

    console.log('UserOperation sent successfully!')
    console.log('UserOp Hash:', userOpHash)
    return userOpHash
}

/**
 * Complete workflow: prepare, sign, and send UserOperation
 */
export async function executeUserOperation(
    client: any,
    config: UserOperationConfig,
    smartAccount: any,
    authorization?: SignAuthorizationReturnType
) {
    // Step 1: Prepare
    const prepared = await prepareUserOp(client, config, smartAccount, authorization)
    // console.log('Prepared UserOperation:', prepared)

    // Step 2: Sign
    const signedUserOp = await signUserOp(smartAccount, prepared)
    console.log('Signed UserOperation:', signedUserOp)

    // Step 3: Send
    const userOpHash = await sendUserOp(client, signedUserOp)

    return userOpHash
}
