// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RestructuredToken
 * @notice Represents uncovered claims post-default
 * @dev Issued when assets are insufficient to cover all claims
 *      Represents:
 *      - Off-chain recovery rights
 *      - Recapitalization participation
 *      - Secondary market tradeable recovery claims
 */
contract RestructuredToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Reference to original RWA token
    address public immutable ORIGINAL_TOKEN;
    
    // Recovery tracking
    uint256 public totalOriginalClaims;
    uint256 public recoveryRatio; // Basis points (10000 = 100%)
    
    // Recovery distribution
    mapping(address => bool) public hasClaimedRecovery;
    uint256 public totalRecoveryDistributed;
    
    // Metadata
    string public restructuringDocumentUri;
    uint256 public restructuringDate;
    
    // Events
    event RecoveryDistributed(address indexed claimant, uint256 amount);
    event RecoveryRatioUpdated(uint256 newRatio);
    event RestructuringDocumentUpdated(string uri);

    constructor(
        string memory name,
        string memory symbol,
        address _originalToken,
        uint256 _totalOriginalClaims,
        address _governance,
        string memory _documentUri
    ) ERC20(name, symbol) {
        require(_originalToken != address(0), "RestructuredToken: invalid original token");
        require(_totalOriginalClaims > 0, "RestructuredToken: invalid claims amount");

        ORIGINAL_TOKEN = _originalToken;
        totalOriginalClaims = _totalOriginalClaims;
        restructuringDate = block.timestamp;
        restructuringDocumentUri = _documentUri;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(MINTER_ROLE, _governance);
    }

    /**
     * @notice Mint restructured tokens to claimants
     * @dev Called during waterfall execution
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Update recovery ratio when assets are recovered
     */
    function updateRecoveryRatio(uint256 _recoveryRatio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_recoveryRatio <= 10000, "RestructuredToken: ratio exceeds 100%");
        recoveryRatio = _recoveryRatio;
        emit RecoveryRatioUpdated(_recoveryRatio);
    }

    /**
     * @notice Calculate recovery amount for a holder
     */
    function calculateRecovery(address holder) external view returns (uint256) {
        uint256 balance = balanceOf(holder);
        return (balance * recoveryRatio) / 10000;
    }

    /**
     * @notice Claim recovery proceeds
     */
    function claimRecovery() external {
        require(!hasClaimedRecovery[msg.sender], "RestructuredToken: already claimed");
        require(recoveryRatio > 0, "RestructuredToken: no recovery available");
        
        uint256 balance = balanceOf(msg.sender);
        require(balance > 0, "RestructuredToken: no balance");
        
        uint256 recoveryAmount = (balance * recoveryRatio) / 10000;
        hasClaimedRecovery[msg.sender] = true;
        totalRecoveryDistributed += recoveryAmount;
        
        // TODO: Transfer actual recovery assets (requires integration with recovery vault)
        
        emit RecoveryDistributed(msg.sender, recoveryAmount);
    }

    /**
     * @notice Update restructuring document URI
     */
    function updateRestructuringDocument(string calldata uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        restructuringDocumentUri = uri;
        emit RestructuringDocumentUpdated(uri);
    }

    /**
     * @notice Get restructuring information
     */
    function getRestructuringInfo() external view returns (
        address original,
        uint256 originalClaims,
        uint256 recovery,
        uint256 date,
        string memory documentUri
    ) {
        return (
            ORIGINAL_TOKEN,
            totalOriginalClaims,
            recoveryRatio,
            restructuringDate,
            restructuringDocumentUri
        );
    }
}
