// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IERC8004Reputation.sol";
import "./IERC8004Identity.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title ERC8004Reputation - ERC-8004 Reputation Registry Implementation
/// @notice Permissionless feedback with Sybil-resistant getSummary() filtering by trusted reviewers
contract ERC8004Reputation is IERC8004Reputation {
    IERC721 public immutable identityRegistry;

    uint256 private _nextFeedbackId;

    // feedbackId => Feedback
    mapping(uint256 => Feedback) private _feedbacks;

    // agentId => list of feedbackIds
    mapping(uint256 => uint256[]) private _agentFeedbackIds;

    constructor(address identityRegistry_) {
        identityRegistry = IERC721(identityRegistry_);
    }

    function submitFeedback(
        uint256 agentId,
        uint8 score,
        string calldata tag,
        string calldata detailURI
    ) external returns (uint256 feedbackId) {
        // Verify agent exists
        require(identityRegistry.ownerOf(agentId) != address(0), "Agent does not exist");
        require(score >= 1 && score <= 5, "Score must be 1-5");

        feedbackId = _nextFeedbackId++;
        _feedbacks[feedbackId] = Feedback({
            reviewer: msg.sender,
            agentId: agentId,
            score: score,
            tag: tag,
            detailURI: detailURI,
            timestamp: block.timestamp
        });
        _agentFeedbackIds[agentId].push(feedbackId);

        emit FeedbackSubmitted(feedbackId, msg.sender, agentId, score, tag);
    }

    function getFeedback(uint256 agentId) external view returns (Feedback[] memory) {
        uint256[] storage ids = _agentFeedbackIds[agentId];
        Feedback[] memory result = new Feedback[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = _feedbacks[ids[i]];
        }
        return result;
    }

    /// @notice Get aggregated summary filtered by trusted reviewers (Sybil resistance)
    /// @dev If trustedReviewers is empty, all feedback is counted
    function getSummary(
        uint256 agentId,
        address[] calldata trustedReviewers
    ) external view returns (Summary memory) {
        uint256[] storage ids = _agentFeedbackIds[agentId];
        uint256 totalScore;
        uint256 count;

        for (uint256 i = 0; i < ids.length; i++) {
            Feedback storage fb = _feedbacks[ids[i]];
            if (trustedReviewers.length == 0 || _isTrusted(fb.reviewer, trustedReviewers)) {
                totalScore += fb.score;
                count++;
            }
        }

        uint256 avgScaled = count > 0 ? (totalScore * 100) / count : 0;
        return Summary({totalReviews: count, averageScore: avgScaled});
    }

    function _isTrusted(address reviewer, address[] calldata trusted) internal pure returns (bool) {
        for (uint256 i = 0; i < trusted.length; i++) {
            if (trusted[i] == reviewer) return true;
        }
        return false;
    }
}
