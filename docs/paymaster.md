# Paymaster

## the risk of abuse or DoS

1. Drain the Paymaster's deposit by spamming invalid operations
2. Trick the Paymaster into sponsoring high-cost or reverted calls
3. Exploit timeouts or race conditions in verification logic

## Features

1. **Daily Sponsorship Limit**: Each user limited to 5 sponsored operations per day (configurable), Prevents malicious users from draining Paymaster by submitting intentionally failing UserOps

2. **High-Cost User Operation Prevent**

3. **Off-Chain Signed Verification**
    - User gets a signed message from a backend
    - paymasterAndData includes the signature and metadata
    - Contract verifies the signature before approving sponsorship