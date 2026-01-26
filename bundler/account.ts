import { commonClient } from './client'
import { toSimple7702SmartAccount } from 'viem/account-abstraction'
import { privateKeyToAccount } from 'viem/accounts'
const owner = privateKeyToAccount('0x...') // add private key here

export const smartAccount = await toSimple7702SmartAccount({
    implementation: "0xa46cc63eBF4Bd77888AA327837d20b23A63a56B5", // simple7702Account for ep9
    client: commonClient,
    owner,
});