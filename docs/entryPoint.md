# EntryPoint

## handleOps

### Validation Phase

1. Validate Input Numbers
    ```
    (
        preVerificationGas |
        verificationGasLimit |
        callGasLimit |
        paymasterVerificationGasLimit |
        paymasterPostOpGasLimit |
        maxFeePerGas |
        maxPriorityFeePerGas
    ) <= type(uint120).max

    ```
2. Validate Account Balance

    The Signature validation is in `IAccount.validateUserOp`, in this method the smart account should deposit to entrypoint if the balance is insufficient.
    ```
    requiredPrefund = (
        verificationGasLimit +
        callGasLimit +
        paymasterVerificationGasLimit +
        preVerificationGas
    ) * maxFeePerGas

    if paymaster == address(0)
        require(balance > requirePrefund)
    ```
3. Validate Nonce
    ```
    uint192 key = uint192(nonce >> 64);
    uint64 seq = uint64(nonce);
    nonceSequenceNumber[sender][key]++ == seq;
    ```
4. Check **verificationGasLimit**
5. Validate Paymaster Balance
6. Call `IPaymaster.validatePaymasterUserOp`
7. Check **paymasterVerificationGasLimit**

### Execution Phase

1. Load method signature from **calldata**.

    If the method signature is `IAccountExecute.executeUserOp`, pass the whole UserOperation into the function.

    If not, it is the normal calldata.

2. Start executing the calldata, check the callGasLimit.

    `gasleft * 63 / 64 > callGasLimit + paymasterPostOpGasLimit + INNER_GAS_OVERHEAD`

    INNER_GAS_OVERHEAD: It acts as a safety buffer to prevent out-of-gas errors caused by underestimating the gas needed for internal logic, memory allocation, or future changes in gas costs.

3. Execute the calldata, if the result is revert, mark `IPaymaster.PostOpMode` as `opReverted`

4. Start Post Execution, add `unUsedGasPanality` for unnecessary high gas limit (10% unused gas charged for penality). `callGasLimit` would affect how many UserOp to be bundled.

5. Execute `IPaymaster.postOp`, also add penality for unnecessary high `paymasterPostOpGasLimit`.

6. Calculate the actual cost, revert if insufficient prefund, update the deposit of payer.

7. Hanle inner operation errors. Informing paymaster the failed UserOperations.

### Compensate Phase

Compensate the bundler