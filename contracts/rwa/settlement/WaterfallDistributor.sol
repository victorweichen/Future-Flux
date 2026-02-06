// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title WaterfallDistributor
 * @notice Enforces deterministic loss ordering during settlement
 * @dev Loss ordering (immutable):
 *      1. Protocol reserves
 *      2. Issuer collateral/margin
 *      3. Insurance funds
 *      4. Liquidity buffers
 *      5. Token holder haircut (proportional)
 */
contract WaterfallDistributor is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant SETTLEMENT_ENGINE_ROLE = keccak256("SETTLEMENT_ENGINE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    enum Tranche {
        PROTOCOL_RESERVES,
        ISSUER_COLLATERAL,
        INSURANCE_FUND,
        LIQUIDITY_BUFFER,
        TOKEN_HOLDERS
    }

    struct TrancheData {
        address fundAddress;
        uint256 amount;
        bool isActive;
    }

    // Waterfall structure
    mapping(Tranche => TrancheData) public tranches;
    
    // Distribution tracking
    uint256 public totalLoss;
    uint256 public distributedAmount;
    mapping(Tranche => uint256) public trancheLosses;
    
    // Token holder haircut tracking
    uint256 public totalClaims;
    uint256 public haircutRatio; // Basis points (10000 = 100%)
    
    // Events
    event WaterfallExecuted(uint256 totalLoss, uint256 timestamp);
    event TrancheLoss(Tranche indexed tranche, uint256 lossAmount);
    event HaircutApplied(uint256 haircutRatio, uint256 totalClaims);
    event TrancheConfigured(Tranche indexed tranche, address fundAddress, uint256 amount);

    constructor(address _governance) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
        
        haircutRatio = 10000; // Default: no haircut (100% recovery)
    }

    /**
     * @notice Configure a tranche in the waterfall
     * @dev Can only be called before execution
     */
    function configureTranche(
        Tranche tranche,
        address fundAddress,
        uint256 amount
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(fundAddress != address(0), "WaterfallDistributor: invalid address");
        require(distributedAmount == 0, "WaterfallDistributor: already executed");
        
        tranches[tranche] = TrancheData({
            fundAddress: fundAddress,
            amount: amount,
            isActive: true
        });
        
        emit TrancheConfigured(tranche, fundAddress, amount);
    }

    /**
     * @notice Execute the waterfall distribution for a given loss
     * @param loss Total loss amount to be distributed
     */
    function executeWaterfall(uint256 loss) external onlyRole(SETTLEMENT_ENGINE_ROLE) nonReentrant {
        require(loss > 0, "WaterfallDistributor: loss must be greater than 0");
        require(distributedAmount == 0, "WaterfallDistributor: already executed");
        
        totalLoss = loss;
        uint256 remainingLoss = loss;
        
        // Tranche 1: Protocol reserves
        remainingLoss = _applyTrancheLoss(Tranche.PROTOCOL_RESERVES, remainingLoss);
        
        // Tranche 2: Issuer collateral
        remainingLoss = _applyTrancheLoss(Tranche.ISSUER_COLLATERAL, remainingLoss);
        
        // Tranche 3: Insurance fund
        remainingLoss = _applyTrancheLoss(Tranche.INSURANCE_FUND, remainingLoss);
        
        // Tranche 4: Liquidity buffer
        remainingLoss = _applyTrancheLoss(Tranche.LIQUIDITY_BUFFER, remainingLoss);
        
        // Tranche 5: Token holders (haircut)
        if (remainingLoss > 0) {
            _applyHaircut(remainingLoss);
        }
        
        distributedAmount = loss - remainingLoss;
        
        emit WaterfallExecuted(loss, block.timestamp);
    }

    /**
     * @dev Apply loss to a specific tranche
     * @return Remaining loss after tranche absorption
     */
    function _applyTrancheLoss(Tranche tranche, uint256 loss) internal returns (uint256) {
        if (loss == 0) return 0;
        
        TrancheData memory trancheData = tranches[tranche];
        if (!trancheData.isActive || trancheData.amount == 0) return loss;
        
        uint256 trancheLoss = loss > trancheData.amount ? trancheData.amount : loss;
        trancheLosses[tranche] = trancheLoss;
        
        emit TrancheLoss(tranche, trancheLoss);
        
        return loss - trancheLoss;
    }

    /**
     * @dev Apply proportional haircut to token holders
     */
    function _applyHaircut(uint256 remainingLoss) internal {
        require(totalClaims > 0, "WaterfallDistributor: no claims to haircut");
        
        // Calculate haircut ratio
        // haircutRatio = (totalClaims - remainingLoss) / totalClaims * 10000
        if (remainingLoss >= totalClaims) {
            haircutRatio = 0; // Total loss
        } else {
            haircutRatio = ((totalClaims - remainingLoss) * 10000) / totalClaims;
        }
        
        trancheLosses[Tranche.TOKEN_HOLDERS] = remainingLoss;
        
        emit HaircutApplied(haircutRatio, totalClaims);
        emit TrancheLoss(Tranche.TOKEN_HOLDERS, remainingLoss);
    }

    /**
     * @notice Set total claims for haircut calculation
     */
    function setTotalClaims(uint256 _totalClaims) external onlyRole(SETTLEMENT_ENGINE_ROLE) {
        require(_totalClaims > 0, "WaterfallDistributor: invalid claims amount");
        totalClaims = _totalClaims;
    }

    /**
     * @notice Calculate recovery amount for a claim
     * @param claimAmount Original claim amount
     * @return Recovery amount after haircut
     */
    function calculateRecovery(uint256 claimAmount) external view returns (uint256) {
        return (claimAmount * haircutRatio) / 10000;
    }

    /**
     * @notice Get total available funds across all tranches
     */
    function getTotalAvailableFunds() external view returns (uint256) {
        uint256 total = 0;
        
        for (uint8 i = 0; i <= uint8(Tranche.LIQUIDITY_BUFFER); i++) {
            TrancheData memory trancheData = tranches[Tranche(i)];
            if (trancheData.isActive) {
                total += trancheData.amount;
            }
        }
        
        return total;
    }

    /**
     * @notice Get loss absorbed by each tranche
     */
    function getTrancheLoss(Tranche tranche) external view returns (uint256) {
        return trancheLosses[tranche];
    }

    /**
     * @notice Check if waterfall has been executed
     */
    function isExecuted() external view returns (bool) {
        return distributedAmount > 0;
    }

    /**
     * @notice Reset waterfall (governance only, for testing or re-execution)
     */
    function reset() external onlyRole(GOVERNANCE_ROLE) {
        totalLoss = 0;
        distributedAmount = 0;
        haircutRatio = 10000;
        
        for (uint8 i = 0; i <= uint8(Tranche.TOKEN_HOLDERS); i++) {
            trancheLosses[Tranche(i)] = 0;
        }
    }
}
