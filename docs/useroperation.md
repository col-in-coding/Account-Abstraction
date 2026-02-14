## UserOperation V0.8.0

### sender

Sender is a Smart Account Address

- For EIP-4337, it's a contract address (could be predicted by create2 if not depolyed)
- For EIP-7702, it's an EOA that supports delegate code

### nonce

Nonce is centralized and managed by the EntryPoint, and it's a key-based nonce system.

```
sequence = entryPoint.getNonce(address(account), key)
nonce = (key << 64) | sequence
```

### initCode

Smart Account initialization

- For EIP-4337, if the account is not deployed
  `initCode = factory(address) + calldata(bytes)`
- For EIP-7702, normally empty, only if the Smart Account needs an initialization
  `initCode = 0x7702(INITCODE_EIP7702_MARKER bytes20) + calldata(bytes)`

### callData

Smart Account execution

### accountGasLimits

`(verificationGasLimit, callGasLimit) = UserOperationLib.unpackUints(accountGasLimits)`

### preVerificationGas

### gasFees

`(maxPriorityFeePerGas, maxFeePerGas) = UserOperationLib.unpackUints(gasFees)`

### paymasterAndData

`paymasterAndData = paymaster(address) + validation gas limit(byte16) + postOp Gas Limit(byte16) + data`

### signature

**Calculate `userOpHash`**

For EIP-7702 accounts, the initCode is replaced in the hash calculation to ensure the UserOperation hash is always unique and consistent for the same delegate and initialization data.

`initCode = op.Sender + calldata(bytes)`

**Validate User Operation**
The signature validation logic is in Smart Account
```
if paymaster == 0
  missingAccountFunds = requiredPrefund - balalance

abi.encodeCall(IAccount.validateUserOp, (op, opInfo.userOpHash, missingAccountFunds))
```