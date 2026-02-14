/**
 * Authorization handling for EIP-7702
 */
import type { SignAuthorizationReturnType } from 'viem'
import type { PublicClient } from 'viem'

export interface AuthorizationCheckResult {
    needsSignature: boolean
    senderCode: string
    authorization?: SignAuthorizationReturnType
}


/**
 * Check and sign EIP-7702 authorization if needed
 */
export async function checkAndSignAuthorization(
    client: any, // PublicClient with EIP-7702 extension
    smartAccountAddress: string,
    delegateAddress: string,
    authorizationParams: { account: any; address: string }
): Promise<AuthorizationCheckResult> {
    // Get the sender's code to check if authorization is needed
    const senderCode = await client.getCode({
        address: smartAccountAddress as `0x${string}`,
    })
    const expectedCode = `0xef0100${delegateAddress.toLowerCase().substring(2)}`
    if (senderCode == expectedCode) {
        console.log('No authorization signature needed - code already deployed')
        return {
            needsSignature: false,
            senderCode: senderCode || '0x',
        }
    }

    console.log('\n=== 🔐 EIP-7702 Authorization Signing Process ===\n')

    // 打印输入参数
    console.log('📝 Input Parameters:')
    console.log('  account:', authorizationParams.account?.address || authorizationParams.account)
    console.log('  delegate address:', authorizationParams.address)

    // 获取链信息
    const chainId = await client.getChainId()
    const nonce = await client.getTransactionCount({
        address: authorizationParams.account?.address || authorizationParams.account,
    })

    console.log('\n📊 Chain & Account Info:')
    console.log('  chainId:', chainId)
    console.log('  nonce:', nonce)

    console.log('\nSigning authorization...')
    const authorization = await client.signAuthorization(authorizationParams)

    // 打印签名结果的中间步骤
    console.log('\n✅ Authorization Signature Generated:')
    console.log('  address:', authorization.address)
    console.log('  chainId:', authorization.chainId)
    console.log('  nonce:', authorization.nonce)
    console.log('  yParity:', authorization.yParity)
    console.log('  r:', authorization.r)
    console.log('  s:', authorization.s)
    console.log('  v:', (authorization as any).v)

    return {
        needsSignature: true,
        senderCode: senderCode || '0x',
        authorization,
    }
}