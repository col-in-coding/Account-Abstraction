import { sepoliaClientV08 } from './modules/client'
import { initializeAccounts, createSmartAccount } from './modules/account'
import { checkAndSignAuthorization } from './modules/authorization'
import { executeUserOperation } from './modules/userOperation'
import { CONTRACTS, DEFAULT_USER_OP_CONFIG, env } from './modules/constants'

async function main() {
    try {
        // Step 1: Initialize accounts
        console.log('📝 Step 1: Initializing accounts...')
        const { owner, recipient } = initializeAccounts({
            ownerPrivateKey: env.PRIVATE_KEY,
            recipientPrivateKey: env.USER_PRIVATE_KEY,
            eip7702DelegateAddress: CONTRACTS.EIP7702_DELEGATE,
            entryPointAddress: CONTRACTS.ENTRY_POINT_V08,
        })

        // Step 2: Create smart account
        console.log('🏗️  Step 2: Creating EIP-7702 smart account...')
        const smartAccount = await createSmartAccount(
            sepoliaClientV08,
            owner,
            CONTRACTS.EIP7702_DELEGATE,
            CONTRACTS.ENTRY_POINT_V08
        )

        // Step 3: Check and sign authorization
        console.log('🔐 Step 3: Checking EIP-7702 authorization...')
        const authResult = await checkAndSignAuthorization(
            sepoliaClientV08,
            smartAccount.address,
            smartAccount.authorization.address,
            smartAccount.authorization
        )

        // Step 4: prepare UserOperation
        console.log('💳 Step 4: Preparing UserOperation...')
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

        console.log('=== Transaction Completed Successfully ===')
        console.log(`UserOp Hash: ${userOpHash}`)
    } catch (error) {
        console.error('❌ Error:', error)
        process.exit(1)
    }
}

main()