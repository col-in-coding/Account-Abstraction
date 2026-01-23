# Abstract Account

## 🏗️ Architecture Overview

```
User → UserOperation → Bundler → EntryPoint → Smart Wallet → Execution
```

## 👥 Key Roles

### **User**
- **Role**: Owner of Smart Contract Account
- **Responsibilities**:
  - Creates and signs UserOperations
  - Manages wallet permissions and recovery
  - Can optionally pre-deposit ETH for gas payments

### **Bundler**
- **Role**: Transaction Packager & MEV Searcher
- **Responsibilities**:
  - Receives UserOperations from users/wallets
  - Validates operations via local simulation
  - Batches multiple UserOps into efficient bundles
  - Calls EntryPoint's `handleOps` method
  - Pays upfront gas costs, receives refunds + fees
  - Protects against DoS and invalid operations

### **EntryPoint Contract**
- **Role**: Singleton Universal Execution Gateway
- **Address**: `0x4337084d9e255ff0702461cf8895ce9e3b5ff108` (cross-chain)
- **Responsibilities**:
  - Validates UserOperation authenticity
  - Enforces security rules and replay protection
  - Executes user intents through smart wallets
  - Handles gas accounting and fee distribution
  - Manages deposit/withdrawal for accounts

### **Paymaster** (Optional)
- **Role**: Gas Fee Sponsor
- **Responsibilities**:
  - Sponsors gas fees for users

## 💰 Payment Methods

### 1. **Self-Paid (User Deposits)**
```solidity
// User pre-deposits ETH for gas
account.addDeposit{value: 1 ether}();

// UserOp without paymaster
userOp.paymasterAndData = "";
```

**Flow**: User Deposit → EntryPoint → Gas Deduction

### 2. **Sponsored (Paymaster)**
```solidity
// Paymaster sponsors the transaction
userOp.paymasterAndData = abi.encodePacked(
    paymasterAddress,
    validUntil,
    validAfter,
    signature
);
```

**Flow**: Paymaster Deposit → EntryPoint → Sponsored Execution

### 3. **Token Payment** (Advanced)
- Pay gas fees using ERC-20 tokens
- Automatic token-to-ETH conversion
- Custom exchange rate logic

---

## 🔄 EIP-7702 Integration (Hybrid Account)

### **What is EIP-7702?**
EIP-7702 allows an EOA (Externally Owned Account) to **temporarily set smart contract code** during a transaction, enabling smart account features while preserving the EOA address.

### **SimpleHybridAccount: Best of Both Worlds**

```
SimpleHybridAccount = EIP-7702 (Batching) + ERC-4337 (Gas Sponsoring)
```

#### **Key Features:**
- ✅ **EIP-7702**: EOA can batch multiple transactions in one block
- ✅ **ERC-4337**: Paymaster can sponsor gas fees
- ✅ **ERC-1271**: Support dApp signature validation
- ✅ **Flexible Payment**: Choose between self-paid or sponsored gas

### **Architecture Comparison**

| Feature | Pure EOA | EIP-7702 Direct | EIP-7702 + ERC-4337 | Pure ERC-4337 |
|---------|----------|-----------------|---------------------|---------------|
| Batching | ❌ | ✅ | ✅ | ✅ |
| Gas Sponsoring | ❌ | ❌ | ✅ | ✅ |
| Smart Contract Logic | ❌ | ✅ | ✅ | ✅ |
| Keep EOA Address | ✅ | ✅ | ✅ | ❌ |
| dApp Compatibility | ✅ | ⚠️ Needs ERC-1271 | ✅ | ✅ |
| Implementation | Native | authorizationList | auth + UserOp | Contract Deploy |

### **Usage Scenarios**

#### **Scenario 1: Owner Direct Call (EIP-7702)**
```javascript
// EOA signs authorization to set code
const auth = signAuthorization({
  chainId: 11155111,
  address: accountImplementation,
  nonce: 0
});

// EOA directly calls execute (owner pays gas)
const tx = await eoaSigner.sendTransaction({
  to: eoaAddress,
  data: encodeExecute(target, value, calldata),
  authorizationList: [auth]
});
```
**Use Case**: Advanced users who hold ETH and want batching capability

#### **Scenario 2: EntryPoint Call (ERC-4337)**
```javascript
// Generate UserOperation
const userOp = {
  sender: accountAddress,
  callData: encodeExecute(target, value, calldata),
  paymasterAndData: paymasterAddress, // Paymaster sponsors gas
  // ...
};

// Submit via Bundler
await bundler.sendUserOperation(userOp);
```
**Use Case**: New users without ETH, or applications wanting to sponsor user transactions

#### **Scenario 3: EIP-7702 + ERC-4337 (Best of Both Worlds)** ✨
```javascript
// Step 1: EOA signs authorization to set code
const auth = signAuthorization({
  chainId: 11155111,
  address: accountImplementation,
  nonce: 0
});

// Step 2: Create UserOperation (sender is the EOA with delegated code)
const userOp = {
  sender: eoaAddress,  // EOA with temporary smart account code
  callData: encodeExecuteBatch(targets, values, datas),
  paymasterAndData: paymasterAddress,  // ✅ Paymaster sponsors gas!
  // ...
};

// Step 3: Submit via Bundler
await bundler.sendUserOperation(userOp);
```
**Use Case**: 
- Keep your EOA address (no need to deploy new contract)
- Batch multiple transactions atomically
- Use Paymaster for gas sponsoring
- **This is the most flexible approach!**

### **When to Use Each Approach?**

#### **Use EIP-7702 Direct Call if:**
- ✅ Users always have ETH for gas
- ✅ Only need batching capability
- ✅ Simple DeFi operations
- ✅ Want minimal overhead

#### **Use EIP-7702 + ERC-4337 (Recommended) if:**
- ✅ Need gas sponsoring (Paymaster)
- ✅ Want to keep EOA address
- ✅ Onboarding new users (no ETH required)
- ✅ Gaming/Social apps (sponsor user actions)
- ✅ Maximum flexibility (can choose to pay or be sponsored)

#### **Use Pure ERC-4337 if:**
- ✅ Building from scratch (no existing EOA)
- ✅ Need complex validation logic (multisig, social recovery)
- ✅ Want full smart account features

### **Contract Structure**

```solidity
SimpleHybridAccount
├── BaseAccount (ERC-4337)
│   └── _validateSignature()      // For EntryPoint validation
├── IERC1271
│   └── isValidSignature()        // For dApp signature validation
├── execute()                     // Single transaction
└── _requireForExecute()
    ├── EntryPoint can call → ERC-4337 + Paymaster
    └── Owner can call → EIP-7702 batching
```

### **Security Model**

**Two Valid Callers:**
1. **EntryPoint** (`msg.sender == entryPoint`)
   - Validates via `_validateSignature(UserOperation)`
   - Supports Paymaster gas sponsoring

2. **Owner** (`msg.sender == owner`)
   - Direct execution via EIP-7702
   - Owner pays gas themselves

**Signature Validation:**
- **ERC-4337**: Uses `_validateSignature()` for UserOperations
- **ERC-1271**: Uses `isValidSignature()` for dApp interactions
- Supports both raw hash and EIP-191 formatted signatures