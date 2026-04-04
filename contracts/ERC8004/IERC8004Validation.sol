// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IERC8004Validation - ERC-8004 Validation Registry Interface
/// @notice Pluggable verification of agent work results
interface IERC8004Validation {
    enum ValidationMethod {
        StakedReExecution,  // Validator re-executes with stake as collateral
        ZkmlProof,          // Zero-knowledge ML proof
        TeeAttestation      // Trusted Execution Environment attestation
    }

    enum ValidationStatus {
        Pending,
        Approved,
        Rejected,
        Disputed
    }

    struct ValidationRequest {
        uint256 agentId;
        address requester;
        bytes32 taskHash;       // hash of the task/output to validate
        string resultURI;       // URI pointing to the work result
        ValidationMethod method;
        ValidationStatus status;
        address validator;
        uint256 stake;          // ETH staked by validator
        uint256 timestamp;
    }

    event ValidationRequested(
        uint256 indexed requestId,
        uint256 indexed agentId,
        bytes32 taskHash,
        ValidationMethod method
    );
    event ValidationSubmitted(
        uint256 indexed requestId,
        address indexed validator,
        ValidationStatus status,
        uint256 stake
    );
    event ValidationDisputed(uint256 indexed requestId, address indexed disputer);

    /// @notice Request validation of an agent's work
    function requestValidation(
        uint256 agentId,
        bytes32 taskHash,
        string calldata resultURI,
        ValidationMethod method
    ) external returns (uint256 requestId);

    /// @notice Validator submits their verdict (with optional stake)
    function submitValidation(
        uint256 requestId,
        ValidationStatus status
    ) external payable;

    /// @notice Dispute a validation result
    function disputeValidation(uint256 requestId) external;

    /// @notice Get validation request details
    function getValidation(uint256 requestId) external view returns (ValidationRequest memory);

    /// @notice Get all validations for an agent
    function getAgentValidations(uint256 agentId) external view returns (uint256[] memory requestIds);
}
