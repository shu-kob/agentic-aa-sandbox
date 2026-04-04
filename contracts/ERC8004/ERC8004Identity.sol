// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC8004Identity.sol";

/// @title ERC8004Identity - ERC-8004 Identity Registry Implementation
/// @notice ERC-721-based agent identity with service endpoints (MCP, A2A, ENS, DID) and linked wallets
contract ERC8004Identity is ERC721, Ownable, IERC8004Identity {
    uint256 private _nextAgentId;

    // agentId => endpointType => url
    mapping(uint256 => mapping(string => string)) private _endpoints;
    // agentId => list of endpoint types (for enumeration)
    mapping(uint256 => string[]) private _endpointTypes;
    // agentId => endpointType => index in _endpointTypes (1-based, 0 = not set)
    mapping(uint256 => mapping(string => uint256)) private _endpointIndex;

    // agentId => linked wallets
    mapping(uint256 => address[]) private _linkedWallets;
    // agentId => wallet => index in _linkedWallets (1-based, 0 = not linked)
    mapping(uint256 => mapping(address => uint256)) private _walletIndex;

    constructor() ERC721("ERC8004AgentID", "AGENT") Ownable(msg.sender) {}

    modifier onlyAgentOwner(uint256 agentId) {
        require(ownerOf(agentId) == msg.sender, "Not agent owner");
        _;
    }

    function registerAgent(address agent) external onlyOwner returns (uint256 agentId) {
        agentId = _nextAgentId++;
        _safeMint(agent, agentId);
        emit AgentRegistered(agent, agentId);
    }

    function setServiceEndpoint(
        uint256 agentId,
        string calldata endpointType,
        string calldata url
    ) external onlyAgentOwner(agentId) {
        require(bytes(url).length > 0, "Empty URL");

        if (_endpointIndex[agentId][endpointType] == 0) {
            // New endpoint type
            _endpointTypes[agentId].push(endpointType);
            _endpointIndex[agentId][endpointType] = _endpointTypes[agentId].length;
        }
        _endpoints[agentId][endpointType] = url;
        emit ServiceEndpointSet(agentId, endpointType, url);
    }

    function removeServiceEndpoint(
        uint256 agentId,
        string calldata endpointType
    ) external onlyAgentOwner(agentId) {
        uint256 idx = _endpointIndex[agentId][endpointType];
        require(idx != 0, "Endpoint not found");

        // Swap-and-pop from _endpointTypes
        uint256 lastIdx = _endpointTypes[agentId].length;
        if (idx != lastIdx) {
            string memory lastType = _endpointTypes[agentId][lastIdx - 1];
            _endpointTypes[agentId][idx - 1] = lastType;
            _endpointIndex[agentId][lastType] = idx;
        }
        _endpointTypes[agentId].pop();
        delete _endpointIndex[agentId][endpointType];
        delete _endpoints[agentId][endpointType];

        emit ServiceEndpointRemoved(agentId, endpointType);
    }

    function linkWallet(uint256 agentId, address wallet) external onlyAgentOwner(agentId) {
        require(wallet != address(0), "Zero address");
        require(_walletIndex[agentId][wallet] == 0, "Already linked");

        _linkedWallets[agentId].push(wallet);
        _walletIndex[agentId][wallet] = _linkedWallets[agentId].length;
        emit WalletLinked(agentId, wallet);
    }

    function unlinkWallet(uint256 agentId, address wallet) external onlyAgentOwner(agentId) {
        uint256 idx = _walletIndex[agentId][wallet];
        require(idx != 0, "Not linked");

        uint256 lastIdx = _linkedWallets[agentId].length;
        if (idx != lastIdx) {
            address lastWallet = _linkedWallets[agentId][lastIdx - 1];
            _linkedWallets[agentId][idx - 1] = lastWallet;
            _walletIndex[agentId][lastWallet] = idx;
        }
        _linkedWallets[agentId].pop();
        delete _walletIndex[agentId][wallet];

        emit WalletUnlinked(agentId, wallet);
    }

    function getServiceEndpoints(uint256 agentId) external view returns (ServiceEndpoint[] memory) {
        string[] storage types = _endpointTypes[agentId];
        ServiceEndpoint[] memory result = new ServiceEndpoint[](types.length);
        for (uint256 i = 0; i < types.length; i++) {
            result[i] = ServiceEndpoint({
                endpointType: types[i],
                url: _endpoints[agentId][types[i]]
            });
        }
        return result;
    }

    function getServiceEndpoint(
        uint256 agentId,
        string calldata endpointType
    ) external view returns (string memory url) {
        return _endpoints[agentId][endpointType];
    }

    function getLinkedWallets(uint256 agentId) external view returns (address[] memory) {
        return _linkedWallets[agentId];
    }

    function isLinkedWallet(uint256 agentId, address wallet) external view returns (bool) {
        return _walletIndex[agentId][wallet] != 0;
    }
}
