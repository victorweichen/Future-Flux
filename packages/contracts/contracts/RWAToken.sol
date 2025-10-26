// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RWAToken
 * @dev ERC20 token representing Real World Assets
 * Can be used as collateral and traded on Future Flux DEX
 */
contract RWAToken is ERC20, Ownable {
    // Asset metadata
    string public assetType;
    string public assetMetadata;
    
    // Token constraints
    uint256 public maxSupply;
    bool public transfersEnabled;

    event TransfersEnabled();
    event TransfersDisabled();
    event AssetMetadataUpdated(string metadata);

    constructor(
        string memory name,
        string memory symbol,
        string memory _assetType,
        uint256 _maxSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        assetType = _assetType;
        maxSupply = _maxSupply;
        transfersEnabled = true;
    }

    /**
     * @dev Mint new tokens (only owner)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max supply exceeded");
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Enable/disable transfers (only owner)
     */
    function setTransfersEnabled(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
        if (enabled) {
            emit TransfersEnabled();
        } else {
            emit TransfersDisabled();
        }
    }

    /**
     * @dev Update asset metadata (only owner)
     */
    function updateAssetMetadata(string memory metadata) external onlyOwner {
        assetMetadata = metadata;
        emit AssetMetadataUpdated(metadata);
    }

    /**
     * @dev Override transfer to check if enabled
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0)) {
            require(transfersEnabled, "Transfers disabled");
        }
        super._update(from, to, value);
    }
}
