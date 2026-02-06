// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IEscrowVault} from "../../interfaces/IEscrowVault.sol";
import {RWAToken} from "./RWAToken.sol";

/**
 * @title MintBurnController
 * @notice Controls RWA token supply based on escrow conditions
 * @dev Enforces invariant: Token Supply = Enforceable Claims
 *      - Minting only when escrow conditions satisfied
 *      - Burning as part of settlement
 */
contract MintBurnController is AccessControl {
    bytes32 public constant SETTLEMENT_ENGINE_ROLE = keccak256("SETTLEMENT_ENGINE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    RWAToken public rwaToken;
    IEscrowVault public escrowVault;
    
    // Mint conditions
    uint256 public collateralRatio; // Basis points (10000 = 100%)
    uint256 public minCollateralAmount;
    
    // Mint tracking
    uint256 public totalMinted;
    uint256 public totalBurned;
    mapping(address => uint256) public mintAllowance;
    
    // Events
    event TokensMinted(address indexed to, uint256 amount, uint256 collateralLocked);
    event TokensBurned(address indexed from, uint256 amount);
    event CollateralRatioUpdated(uint256 newRatio);
    event MintAllowanceSet(address indexed account, uint256 allowance);

    constructor(
        address _rwaToken,
        address _escrowVault,
        address _governance,
        uint256 _collateralRatio
    ) {
        require(_rwaToken != address(0), "MintBurnController: invalid token");
        require(_escrowVault != address(0), "MintBurnController: invalid vault");
        require(_collateralRatio >= 10000, "MintBurnController: ratio must be >= 100%");
        
        rwaToken = RWAToken(_rwaToken);
        escrowVault = IEscrowVault(_escrowVault);
        collateralRatio = _collateralRatio;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
    }

    /**
     * @notice Mint tokens if collateral conditions are met
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(SETTLEMENT_ENGINE_ROLE) {
        require(amount > 0, "MintBurnController: amount must be greater than 0");
        require(to != address(0), "MintBurnController: invalid recipient");
        
        // Check collateral requirements
        uint256 requiredCollateral = (amount * collateralRatio) / 10000;
        uint256 availableCollateral = escrowVault.getTotalValueLocked();
        
        require(
            availableCollateral >= requiredCollateral,
            "MintBurnController: insufficient collateral"
        );
        
        // Mint tokens
        rwaToken.mint(to, amount);
        totalMinted += amount;
        
        emit TokensMinted(to, amount, requiredCollateral);
    }

    /**
     * @notice Mint tokens with explicit allowance (for authorized issuers)
     */
    function mintWithAllowance(address to, uint256 amount) external {
        require(amount > 0, "MintBurnController: amount must be greater than 0");
        require(mintAllowance[msg.sender] >= amount, "MintBurnController: insufficient allowance");
        
        mintAllowance[msg.sender] -= amount;
        
        rwaToken.mint(to, amount);
        totalMinted += amount;
        
        emit TokensMinted(to, amount, 0);
    }

    /**
     * @notice Burn tokens during settlement
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyRole(SETTLEMENT_ENGINE_ROLE) {
        require(amount > 0, "MintBurnController: amount must be greater than 0");
        
        rwaToken.burn(from, amount);
        totalBurned += amount;
        
        emit TokensBurned(from, amount);
    }

    /**
     * @notice Set mint allowance for an address
     */
    function setMintAllowance(address account, uint256 allowance) external onlyRole(GOVERNANCE_ROLE) {
        mintAllowance[account] = allowance;
        emit MintAllowanceSet(account, allowance);
    }

    /**
     * @notice Update collateral ratio
     */
    function setCollateralRatio(uint256 _collateralRatio) external onlyRole(GOVERNANCE_ROLE) {
        require(_collateralRatio >= 10000, "MintBurnController: ratio must be >= 100%");
        collateralRatio = _collateralRatio;
        emit CollateralRatioUpdated(_collateralRatio);
    }

    /**
     * @notice Get current supply metrics
     */
    function getSupplyMetrics() external view returns (
        uint256 currentSupply,
        uint256 minted,
        uint256 burned,
        uint256 netSupply
    ) {
        return (
            rwaToken.totalSupply(),
            totalMinted,
            totalBurned,
            totalMinted - totalBurned
        );
    }

    /**
     * @notice Check if minting is allowed for a given amount
     */
    function canMint(uint256 amount) external view returns (bool) {
        uint256 requiredCollateral = (amount * collateralRatio) / 10000;
        uint256 availableCollateral = escrowVault.getTotalValueLocked();
        return availableCollateral >= requiredCollateral;
    }
}
