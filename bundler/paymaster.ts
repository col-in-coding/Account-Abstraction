import { http } from "viem"
import { createPaymasterClient } from "viem/account-abstraction"

export const paymasterClient = createPaymasterClient({
    transport: http("") // add paymaster url here
});

// NOTE: this can change according to the paymaster implementation.
// use the corresponding paymaster's docs to understand what has to used for context.
export const paymasterContext = { policyId: "" } // add policy id here