// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title IdentityRegistry - ERC721-based Agent ID minting
contract IdentityRegistry is ERC721, Ownable {
    uint256 private _nextTokenId;

    event AgentRegistered(address indexed agent, uint256 indexed tokenId);

    constructor() ERC721("AgentID", "AID") Ownable(msg.sender) {}

    /// @notice Mint a new Agent ID NFT to the given address
    function registerAgent(address agent) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(agent, tokenId);
        emit AgentRegistered(agent, tokenId);
        return tokenId;
    }
}

/// @title ReputationRegistry - Tracks success tasks and scores per Agent ID
contract ReputationRegistry is Ownable {
    struct Reputation {
        uint256 successTasks;
        uint256 score;
    }

    mapping(uint256 => Reputation) public reputations;

    IdentityRegistry public immutable identityRegistry;

    event ReputationUpdated(uint256 indexed agentId, uint256 successTasks, uint256 score);

    constructor(address identityRegistry_) Ownable(msg.sender) {
        identityRegistry = IdentityRegistry(identityRegistry_);
    }

    /// @notice Increment success task count and add to score for an Agent ID
    function recordSuccess(uint256 agentId, uint256 scoreIncrement) external onlyOwner {
        require(identityRegistry.ownerOf(agentId) != address(0), "Agent ID does not exist");
        Reputation storage rep = reputations[agentId];
        rep.successTasks += 1;
        rep.score += scoreIncrement;
        emit ReputationUpdated(agentId, rep.successTasks, rep.score);
    }

    /// @notice Get reputation data for an Agent ID
    function getReputation(uint256 agentId) external view returns (uint256 successTasks, uint256 score) {
        Reputation storage rep = reputations[agentId];
        return (rep.successTasks, rep.score);
    }
}
