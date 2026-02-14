import { config } from 'dotenv'

config({ path: '../.env' })

export const env = {
	PRIVATE_KEY: process.env.PRIVATE_KEY!,
	USER_PRIVATE_KEY: process.env.USER_PRIVATE_KEY!,
	PAYMASTER_PRIVATE_KEY: process.env.PAYMASTER_PRIVATE_KEY!,
	ETHERSPOT_API_KEY: process.env.ETHERSPOT_API_KEY!,
}

export const BUNDLER_URL = 'https://testnet-rpc.etherspot.io/v3/11155111?api-key=' + env.ETHERSPOT_API_KEY;

export const CONTRACTS = {
    EIP7702_DELEGATE: '0xCeEe3852dde1bB6FdF0bB2d1402A6f6B84Ab49d2',
    ENTRY_POINT_V08: '0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108',
    PAYMASTER: '0x9B7CD9ad5D5B314199dD17d0854d0f8002c46314', // Your custom Paymaster on Sepolia
} as const

export const DEFAULT_USER_OP_CONFIG = {
    amount: '0.0000001', // in ether
    verificationGasLimit: 150000n,
} as const
