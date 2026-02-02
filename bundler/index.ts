import { env } from './config'
import { sepoliaClientV08 } from './client'
import { prepareUserOperation } from 'viem/account-abstraction'
import { toSimple7702SmartAccount, sendUserOperation} from 'viem/account-abstraction'
import { privateKeyToAccount } from 'viem/accounts'
import { parseUnits, SignAuthorizationReturnType } from 'viem'

// const owner = privateKeyToAccount(env.PRIVATE_KEY)
const owner = privateKeyToAccount(env.PAYMASTER_PRIVATE_KEY)
const recipient = privateKeyToAccount(env.USER_PRIVATE_KEY)

// Simple7702SmartAccount Implementation
const eip7702delegate = "0xCeEe3852dde1bB6FdF0bB2d1402A6f6B84Ab49d2"
// EntryPoint V0.8
const entryPointAddr = "0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108"

const smartAccount = await toSimple7702SmartAccount({
    implementation: eip7702delegate,
    client: sepoliaClientV08,
    owner,
})
console.log("Owner address:", owner.address)
console.log("Recipient address:", recipient.address)

// overriding for ep9 address
smartAccount.entryPoint.address = entryPointAddr
console.log("wallet:: ", smartAccount.address)

// check sender's code to decide if eip7702Auth tuple is necessary for userOp.
const senderCode = await sepoliaClientV08.getCode({
    address: smartAccount.address
})
console.log("Sender code: ", senderCode)

let authorization: SignAuthorizationReturnType | undefined
const { address: delegateAddress } = smartAccount.authorization
console.log("Delegate address:", delegateAddress)
console.log("Authorization params:", smartAccount.authorization)

if(senderCode !== `0xef0100${delegateAddress.toLowerCase().substring(2)}`) {
    console.log("Signing authorization...")
    authorization = await sepoliaClientV08.signAuthorization(smartAccount.authorization)
    // console.log("Authorization signature:", authorization)
}

// const userOpHash = await sendUserOperation(sepoliaClientV08, {
//     account: smartAccount,
//     authorization,
//     calls: [
//         {
//             to: recipient.address,
//             value: parseUnits('0.0000001', 18)
//         }
//     ],
//     verificationGasLimit: 150000n
// })

// console.log('userOpHash:: ', userOpHash)

const prepared = await prepareUserOperation(sepoliaClientV08, {
    account: smartAccount,
    authorization,
    calls: [
        {
            to: recipient.address,
            value: parseUnits('0.0000001', 18)
        }
    ],
    verificationGasLimit: 150000n
})

console.log('Prepared UserOperation: ', prepared)
// const userOpHash = await sendUserOperation(sepoliaClientV08, prepared)
// console.log('userOpHash:: ', userOpHash)