// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IComplianceModule} from "../../interfaces/IComplianceModule.sol";

/**
 * @title RWAToken
 * @notice ERC-20 token representing conditional claims on real-world assets
 * @dev Features:
 *      - Transfer restrictions via compliance layer
 *      - Supply linked to escrow state
 *      - Settlement state awareness
 */
contract RWAToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");

    IComplianceModule public complianceModule;
    bool public transfersEnabled;

    // Token metadata
    string public assetDescription;
    string public legalDocumentUri;

    // Events
    event ComplianceModuleUpdated(address indexed newModule);
    event TransfersToggled(bool enabled);
    event TokenMetadataUpdated(string description, string documentUri);

    modifier whenTransfersEnabled() {
        _whenTransfersEnabled();
        _;
    }

    function _whenTransfersEnabled() internal view {
        require(transfersEnabled, "RWAToken: transfers disabled");
    }

    constructor(
        string memory name,
        string memory symbol,
        address _governance,
        string memory _assetDescription,
        string memory _legalDocumentUri
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(COMPLIANCE_ADMIN_ROLE, _governance);

        transfersEnabled = true;
        assetDescription = _assetDescription;
        legalDocumentUri = _legalDocumentUri;
    }

    /**
     * @notice Mint new tokens (only by authorized minter)
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens (only by authorized burner)
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @notice Override transfer to include compliance checks
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Skip checks for minting and burning
        if (from != address(0) && to != address(0)) {
            require(transfersEnabled, "RWAToken: transfers disabled");

            // Apply compliance module if set
            if (address(complianceModule) != address(0)) {
                require(
                    complianceModule.canTransfer(from, to, amount),
                    "RWAToken: transfer not compliant"
                );
            }
        }

        super._update(from, to, amount);
    }

    /**
     * @notice Set compliance module
     */
    function setComplianceModule(address _complianceModule) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        complianceModule = IComplianceModule(_complianceModule);
        emit ComplianceModuleUpdated(_complianceModule);
    }

    /**
     * @notice Toggle transfers (emergency use)
     */
    function setTransfersEnabled(bool _enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transfersEnabled = _enabled;
        emit TransfersToggled(_enabled);
    }

    /**
     * @notice Update token metadata
     */
    function updateMetadata(
        string calldata _description,
        string calldata _documentUri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        assetDescription = _description;
        legalDocumentUri = _documentUri;
        emit TokenMetadataUpdated(_description, _documentUri);
    }
}
