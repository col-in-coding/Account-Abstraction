/**
 * Main entry point - EIP-7702 Smart Account Transaction Flow
 *
 * This script demonstrates:
 * 1. Account initialization
 * 2. Authorization signing (if needed)
 * 3. UserOperation preparation, signing, and sending
 */

import { env } from './config'
import { sepoliaClientV08 } from './client'
import { initializeAccounts, createSmartAccount } from './modules/account'
import { checkAndSignAuthorization } from './modules/authorization'
import { executeUserOperation } from './modules/userOperation'
import { CONTRACTS, DEFAULT_USER_OP_CONFIG } from './modules/constants'

async function main() {
    try {
        console.log('=== EIP-7702 Smart Account Transaction Flow ===\n')

        // Step 1: Initialize accounts
        console.log('📝 Step 1: Initializing accounts...')
        const { owner, recipient } = initializeAccounts({
            ownerPrivateKey: env.PRIVATE_KEY,
            recipientPrivateKey: env.USER_PRIVATE_KEY,
            eip7702DelegateAddress: CONTRACTS.EIP7702_DELEGATE,
            entryPointAddress: CONTRACTS.ENTRY_POINT_V08,
        })
        console.log('✓ Accounts initialized\n')

        // Step 2: Create smart account
        console.log('🏗️  Step 2: Creating EIP-7702 smart account...')
        const smartAccount = await createSmartAccount(
            sepoliaClientV08,
            owner,
            CONTRACTS.EIP7702_DELEGATE,
            CONTRACTS.ENTRY_POINT_V08
        )
        console.log('✓ Smart account created\n')

        // Step 3: Check and sign authorization
        console.log('🔐 Step 3: Checking EIP-7702 authorization...')
        const authResult = await checkAndSignAuthorization(
            sepoliaClientV08,
            smartAccount.address,
            smartAccount.authorization.address,
            smartAccount.authorization
        )
        console.log(
            authResult.needsSignature
                ? '✓ Authorization signed\n'
                : '✓ No authorization needed\n'
        )

        // Step 4: Execute UserOperation
        console.log('💳 Step 4: Executing UserOperation...')
        const userOpHash = await executeUserOperation(
            sepoliaClientV08,
            {
                recipient: recipient.address,
                amount: DEFAULT_USER_OP_CONFIG.amount,
                verificationGasLimit: DEFAULT_USER_OP_CONFIG.verificationGasLimit,
            },
            smartAccount,
            authResult.authorization
        )
        console.log('✓ UserOperation executed\n')

        console.log('=== Transaction Completed Successfully ===')
        console.log(`UserOp Hash: ${userOpHash}`)
    } catch (error) {
        console.error('❌ Error:', error)
        process.exit(1)
    }
}

main()