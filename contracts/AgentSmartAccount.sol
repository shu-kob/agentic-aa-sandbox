// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title AgentSmartAccount - Mock smart account with delegate spend limits (EIP-7702 / ERC-4337 inspired)
contract AgentSmartAccount {
    address public owner;

    struct Delegation {
        uint256 spendLimit;   // Maximum ETH the delegate can spend
        uint256 spent;        // Amount already spent
        bool active;
    }

    /// @notice ERC-4337-like UserOperation structure
    struct UserOperation {
        address delegate;
        address payable to;
        uint256 value;
        bytes data;
        uint256 nonce;
        bytes signature;
    }

    mapping(address => Delegation) public delegations;
    mapping(address => uint256) public nonces;

    event DelegationGranted(address indexed delegate, uint256 spendLimit);
    event DelegationRevoked(address indexed delegate);
    event OperationExecuted(address indexed delegate, address indexed to, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() payable {
        owner = msg.sender;
    }

    receive() external payable {}

    /// @notice Owner grants a delegate a spend limit
    function grantDelegation(address delegate, uint256 spendLimit) external onlyOwner {
        delegations[delegate] = Delegation({
            spendLimit: spendLimit,
            spent: 0,
            active: true
        });
        emit DelegationGranted(delegate, spendLimit);
    }

    /// @notice Owner revokes a delegation
    function revokeDelegation(address delegate) external onlyOwner {
        delegations[delegate].active = false;
        emit DelegationRevoked(delegate);
    }

    /// @notice Execute a UserOperation submitted by a delegate
    /// @dev Verifies ECDSA signature over (delegate, to, value, data, nonce, address(this))
    function executeOperation(UserOperation calldata op) external {
        Delegation storage del = delegations[op.delegate];
        require(del.active, "Delegation not active");
        require(del.spent + op.value <= del.spendLimit, "Exceeds spend limit");

        // Verify nonce
        require(op.nonce == nonces[op.delegate], "Invalid nonce");

        // Verify signature
        bytes32 hash = _operationHash(op);
        address signer = _recoverSigner(hash, op.signature);
        require(signer == op.delegate, "Invalid signature");

        // Update state before external call (CEI pattern)
        del.spent += op.value;
        nonces[op.delegate] += 1;

        // Execute
        (bool success, ) = op.to.call{value: op.value}(op.data);
        require(success, "Execution failed");

        emit OperationExecuted(op.delegate, op.to, op.value);
    }

    /// @notice Compute EIP-712-like hash for a UserOperation
    function _operationHash(UserOperation calldata op) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(abi.encode(
                    op.delegate,
                    op.to,
                    op.value,
                    keccak256(op.data),
                    op.nonce,
                    address(this)
                ))
            )
        );
    }

    function _recoverSigner(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(hash, v, r, s);
    }

    /// @notice Get remaining spend allowance for a delegate
    function remainingAllowance(address delegate) external view returns (uint256) {
        Delegation storage del = delegations[delegate];
        if (!del.active) return 0;
        return del.spendLimit - del.spent;
    }
}
