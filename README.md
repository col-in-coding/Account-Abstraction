# Account Abstraction

## Features

### Batch Execution

Execute multiple transactions in a single call using EIP-7702. The EOA can delegate its code to `Simple7702Account` contract, enabling batch operations while maintaining the original address.

**Key Benefits:**
- Batch multiple transfers or contract calls in one transaction
- Reduce gas costs by combining operations
- Single signature for multiple actions

**Supported Operations:**
- `execute(address, uint256, bytes)` - Single call execution
- `executeBatch(Call[])` - Multiple calls in one transaction

### Gas Sponsorship

Paymaster contract sponsors gas fees for user operations through EIP-4337. Users can execute transactions without holding ETH for gas.

**Key Features:**
- Signature-based verification for authorized sponsorship
- Configurable gas limits per operation
- Daily sponsorship limits per user
- Time-based validation (validAfter/validUntil)

## Notes

[EIP-4337](./docs/eip4337.md)

[EIP-7702](./docs/eip7702.md)

[UserOperation V0.8](./docs/useroperation.md)

[EntryPoint](./docs/entryPoint.md)

[Paymaster](./docs/paymaster.md)