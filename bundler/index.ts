import {config} from 'dotenv'
import { commonClient } from './client'
import { toSimple7702SmartAccount } from 'viem/account-abstraction'
import { privateKeyToAccount } from 'viem/accounts'
import { parseUnits, SignAuthorizationReturnType } from 'viem'

config({ path: '../.env' });
const owner = privateKeyToAccount(process.env.PRIVATE_KEY!) // add private key here

const smartAccount = await toSimple7702SmartAccount({
    implementation: "0xa46cc63eBF4Bd77888AA327837d20b23A63a56B5", // simple7702Account for ep9
    client: commonClient,
    owner,
})

// overriding for ep9 address
smartAccount.entryPoint.address = "0x433709009B8330FDa32311DF1C2AFA402eD8D009"
console.log("wallet:: ", smartAccount.address)

// check sender's code to decide if eip7702Auth tuple is necessary for userOp.
const senderCode = await commonClient.getCode({
    address: smartAccount.address
})

let authorization: SignAuthorizationReturnType | undefined
const { address: delegateAddress } = smartAccount.authorization

if(senderCode !== `0xef0100${delegateAddress.toLowerCase().substring(2)}`) {
    console.log("Signing authorization...")
    authorization = await commonClient.signAuthorization(smartAccount.authorization)
}

const userOpHash = await commonClient.sendUserOperation({
    account: smartAccount,
    authorization,
    calls: [
        {
            to: "0x09FD4F6088f2025427AB1e89257A44747081Ed59",
            value: parseUnits('0.0000001', 18)
        }
    ]
})

console.log('userOpHash:: ', userOpHash)