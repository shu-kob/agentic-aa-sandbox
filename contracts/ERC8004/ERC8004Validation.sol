// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IERC8004Validation.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title ERC8004Validation - ERC-8004 Validation Registry Implementation
/// @notice Pluggable verification: staked re-execution, zkML proof, TEE attestation
contract ERC8004Validation is IERC8004Validation {
    IERC721 public immutable identityRegistry;

    uint256 private _nextRequestId;

    // requestId => ValidationRequest
    mapping(uint256 => ValidationRequest) private _requests;

    // agentId => list of requestIds
    mapping(uint256 => uint256[]) private _agentRequests;

    constructor(address identityRegistry_) {
        identityRegistry = IERC721(identityRegistry_);
    }

    function requestValidation(
        uint256 agentId,
        bytes32 taskHash,
        string calldata resultURI,
        ValidationMethod method
    ) external returns (uint256 requestId) {
        require(identityRegistry.ownerOf(agentId) != address(0), "Agent does not exist");

        requestId = _nextRequestId++;
        _requests[requestId] = ValidationRequest({
            agentId: agentId,
            requester: msg.sender,
            taskHash: taskHash,
            resultURI: resultURI,
            method: method,
            status: ValidationStatus.Pending,
            validator: address(0),
            stake: 0,
            timestamp: block.timestamp
        });
        _agentRequests[agentId].push(requestId);

        emit ValidationRequested(requestId, agentId, taskHash, method);
    }

    function submitValidation(
        uint256 requestId,
        ValidationStatus status
    ) external payable {
        ValidationRequest storage req = _requests[requestId];
        require(req.timestamp != 0, "Request does not exist");
        require(req.status == ValidationStatus.Pending, "Already validated");
        require(
            status == ValidationStatus.Approved || status == ValidationStatus.Rejected,
            "Invalid status"
        );

        req.validator = msg.sender;
        req.status = status;
        req.stake = msg.value;

        emit ValidationSubmitted(requestId, msg.sender, status, msg.value);
    }

    function disputeValidation(uint256 requestId) external {
        ValidationRequest storage req = _requests[requestId];
        require(req.timestamp != 0, "Request does not exist");
        require(
            req.status == ValidationStatus.Approved || req.status == ValidationStatus.Rejected,
            "Not yet validated"
        );

        req.status = ValidationStatus.Disputed;
        emit ValidationDisputed(requestId, msg.sender);
    }

    function getValidation(uint256 requestId) external view returns (ValidationRequest memory) {
        return _requests[requestId];
    }

    function getAgentValidations(uint256 agentId) external view returns (uint256[] memory) {
        return _agentRequests[agentId];
    }
}
