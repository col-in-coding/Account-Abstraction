/**
 * Account initialization and setup
 */
import { toSimple7702SmartAccount } from 'viem/account-abstraction'
import { privateKeyToAccount } from 'viem/accounts'
import type { PublicClient } from 'viem'

export interface AccountConfig {
    ownerPrivateKey: string
    recipientPrivateKey: string
    eip7702DelegateAddress: string
    entryPointAddress: string
}

export interface SmartAccountSetup {
    owner: ReturnType<typeof privateKeyToAccount>
    recipient: ReturnType<typeof privateKeyToAccount>
    smartAccount: Awaited<ReturnType<typeof toSimple7702SmartAccount>>
}

/**
 * Initialize owner and recipient accounts from private keys
 */
export function initializeAccounts(config: AccountConfig) {
    const owner = privateKeyToAccount(config.ownerPrivateKey as `0x${string}`)
    const recipient = privateKeyToAccount(config.recipientPrivateKey as `0x${string}`)

    console.log('Owner address:', owner.address)
    console.log('Recipient address:', recipient.address)

    return { owner, recipient }
}

/**
 * Create a Simple7702 Smart Account
 */
export async function createSmartAccount(
    client: PublicClient,
    owner: ReturnType<typeof privateKeyToAccount>,
    eip7702DelegateAddress: string,
    entryPointAddress: string
) {
    const smartAccount = await toSimple7702SmartAccount({
        implementation: eip7702DelegateAddress as `0x${string}`,
        client,
        owner,
    })

    // Override EntryPoint address
    smartAccount.entryPoint.address = entryPointAddress as `0x${string}`

    console.log('Smart account address:', smartAccount.address)
    console.log('Delegate address:', smartAccount.authorization.address)

    return smartAccount
}
