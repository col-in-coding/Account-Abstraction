import { sendUserOperation } from 'viem/account-abstraction'
import { sepoliaClientV08 } from './modules/client'
import { initializeAccounts, createSmartAccount } from './modules/account'
import { checkAndSignAuthorization } from './modules/authorization'
import { prepareAndSignUserOperation } from './modules/userOperation'
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
        const signedUserOp = await prepareAndSignUserOperation(
            sepoliaClientV08,
            {
                recipient: recipient.address,
                amount: DEFAULT_USER_OP_CONFIG.amount,
                verificationGasLimit: DEFAULT_USER_OP_CONFIG.verificationGasLimit,
            },
            smartAccount,
            authResult.authorization
        )

        // Step 5: Send UserOperation to bundler
        console.log('📤 Step 5: Sending UserOperation to bundler...')
        console.log('  Using bundler URL:', sepoliaClientV08.transport.url || 'default')

        try {
            const userOpHash = await sendUserOperation(sepoliaClientV08, signedUserOp)
            console.log('✓ UserOperation sent to bundler successfully')
            console.log('\n=== UserOperation Submitted ===')
            console.log(`UserOp Hash: ${userOpHash}`)

            // Wait for transaction receipt
            console.log('\n⏳ Waiting for bundler to process the UserOperation...')
            console.log('   (This may take 10-30 seconds)')

            // Poll for receipt
            let receipt = null
            let attempts = 0
            const maxAttempts = 30

            while (attempts < maxAttempts) {
                try {
                    receipt = await sepoliaClientV08.request({
                        method: 'eth_getUserOperationReceipt' as any,
                        params: [userOpHash],
                    })

                    if (receipt) {
                        break
                    }
                } catch (error) {
                    // Receipt not found yet, continue polling
                }

                await new Promise(resolve => setTimeout(resolve, 2000)) // Wait 2 seconds
                attempts++
                process.stdout.write('.')
            }

            console.log('\n')

            if (receipt) {
                console.log('✅ Transaction mined successfully!')
                console.log(`Transaction Hash: ${(receipt as any).receipt?.transactionHash}`)
                console.log(`Block Number: ${(receipt as any).receipt?.blockNumber}`)
                console.log(`Gas Used: ${(receipt as any).actualGasUsed}`)
                console.log(`\nView on Etherscan: https://sepolia.etherscan.io/tx/${(receipt as any).receipt?.transactionHash}`)
            } else {
                console.log('⚠️  Timeout waiting for transaction receipt')
                console.log('   Your UserOperation may still be processed.')
                console.log(`   Check status later with UserOp Hash: ${userOpHash}`)
            }
        } catch (sendError) {
            console.error('❌ Failed to send UserOperation:', sendError)
            throw sendError
        }
    } catch (error) {
        console.error('❌ Error:', error)
        process.exit(1)
    }
}

main()