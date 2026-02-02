import { config } from 'dotenv'

config({ path: '../.env' })

export const env = {
	PRIVATE_KEY: process.env.PRIVATE_KEY!,
	USER_PRIVATE_KEY: process.env.USER_PRIVATE_KEY!,
	PAYMASTER_PRIVATE_KEY: process.env.PAYMASTER_PRIVATE_KEY!,
	ETHERSPOT_API_KEY: process.env.ETHERSPOT_API_KEY!,
}