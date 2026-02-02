import { createFreeBundler, getFreeBundlerUrl, getSupportedChainIds} from '@etherspot/free-bundler'
import {publicActions, walletActions, createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'
import { env } from './config'
const chain = sepolia

// // etherspot free bundler info
// const supportedChainIds = getSupportedChainIds();
// const bundlerAndRpcUrl = getFreeBundlerUrl(chain.id);
// console.log('Supported Chain IDs: ', supportedChainIds);
// console.log('Bundler and RPC URL for Sepolia: ', bundlerAndRpcUrl);
export const sepoliaClientV09 = createFreeBundler({chain})
                                .extend(publicActions)
                                .extend(walletActions)

const bundlerUrl = 'https://testnet-rpc.etherspot.io/v3/11155111?api-key=' + env.ETHERSPOT_API_KEY;
export const sepoliaClientV08 = createPublicClient({
  chain: sepolia,
  transport: http(bundlerUrl),
}).extend(publicActions).extend(walletActions);

const entryPoints = await sepoliaClientV08.request({
  method: 'eth_supportedEntryPoints',
  params: [],
});
console.log("Supported Entry Points: ", entryPoints);
