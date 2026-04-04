// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IERC8004Reputation - ERC-8004 Reputation Registry Interface
/// @notice Permissionless feedback system with Sybil-resistant summary filtering
interface IERC8004Reputation {
    struct Feedback {
        address reviewer;    // who left the feedback
        uint256 agentId;     // target agent
        uint8 score;         // 1-5 rating
        string tag;          // e.g., "reliable", "fast", "low-quality"
        string detailURI;    // IPFS or HTTP URI with detailed review
        uint256 timestamp;
    }

    struct Summary {
        uint256 totalReviews;
        uint256 averageScore; // scaled by 100 (e.g., 450 = 4.50)
    }

    event FeedbackSubmitted(
        uint256 indexed feedbackId,
        address indexed reviewer,
        uint256 indexed agentId,
        uint8 score,
        string tag
    );

    /// @notice Submit feedback for an agent (permissionless)
    function submitFeedback(
        uint256 agentId,
        uint8 score,
        string calldata tag,
        string calldata detailURI
    ) external returns (uint256 feedbackId);

    /// @notice Get all feedback for an agent
    function getFeedback(uint256 agentId) external view returns (Feedback[] memory);

    /// @notice Get aggregated summary, filtered by trusted reviewers (Sybil resistance)
    /// @param agentId The agent to query
    /// @param trustedReviewers Only count feedback from these addresses. Empty = all.
    function getSummary(uint256 agentId, address[] calldata trustedReviewers) external view returns (Summary memory);
}
