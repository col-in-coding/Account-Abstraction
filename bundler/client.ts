import { createFreeBundler } from '@etherspot/free-bundler'
import { publicActions, walletActions } from 'viem'
import { sepolia } from 'viem/chains'
const chain = sepolia

export const commonClient = createFreeBundler({chain})
                                .extend(publicActions)
                                .extend(walletActions)