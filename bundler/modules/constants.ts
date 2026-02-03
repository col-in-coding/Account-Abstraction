/**
 * Configuration and constants
 */

export const CONTRACTS = {
    EIP7702_DELEGATE: '0xCeEe3852dde1bB6FdF0bB2d1402A6f6B84Ab49d2',
    ENTRY_POINT_V08: '0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108',
} as const

export const DEFAULT_USER_OP_CONFIG = {
    amount: '0.0000001', // in ether
    verificationGasLimit: 150000n,
} as const
