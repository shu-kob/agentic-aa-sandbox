// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IERC8004Identity - ERC-8004 Identity Registry Interface
/// @notice ERC-721-based agent identity with service endpoints and wallet metadata
interface IERC8004Identity {
    /// @notice Service endpoint types (MCP, A2A, ENS, DID, etc.)
    struct ServiceEndpoint {
        string endpointType; // e.g., "mcp", "a2a", "ens", "did"
        string url;          // endpoint URL or identifier
    }

    event AgentRegistered(address indexed agent, uint256 indexed agentId);
    event ServiceEndpointSet(uint256 indexed agentId, string endpointType, string url);
    event ServiceEndpointRemoved(uint256 indexed agentId, string endpointType);
    event WalletLinked(uint256 indexed agentId, address indexed wallet);
    event WalletUnlinked(uint256 indexed agentId, address indexed wallet);

    /// @notice Register a new agent and mint an identity NFT
    function registerAgent(address agent) external returns (uint256 agentId);

    /// @notice Set a service endpoint for an agent
    function setServiceEndpoint(uint256 agentId, string calldata endpointType, string calldata url) external;

    /// @notice Remove a service endpoint
    function removeServiceEndpoint(uint256 agentId, string calldata endpointType) external;

    /// @notice Link an additional wallet address to an agent
    function linkWallet(uint256 agentId, address wallet) external;

    /// @notice Unlink a wallet address from an agent
    function unlinkWallet(uint256 agentId, address wallet) external;

    /// @notice Get all service endpoints for an agent
    function getServiceEndpoints(uint256 agentId) external view returns (ServiceEndpoint[] memory);

    /// @notice Get a specific service endpoint
    function getServiceEndpoint(uint256 agentId, string calldata endpointType) external view returns (string memory url);

    /// @notice Get all linked wallets for an agent
    function getLinkedWallets(uint256 agentId) external view returns (address[] memory);

    /// @notice Check if an address is a linked wallet of an agent
    function isLinkedWallet(uint256 agentId, address wallet) external view returns (bool);
}
