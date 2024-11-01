// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SalukiToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    // Total supply: 100 billion tokens (1000 * 10^9)
    uint256 public constant TOTAL_SUPPLY = 1000 * 10 ** 9 * 10 ** 18;
    // Private sale allocation: 50 billion tokens (500 * 10^9)
    uint256 public constant PRIVATE_SALE_SUPPLY = 500 * 10 ** 9 * 10 ** 18;
    // Sale price: 59 USDT (6 decimals)
    uint256 public constant SALE_PRICE = 59 * 10 ** 6;
    // Tokens per purchase: 25 million tokens
    uint256 public constant TOKENS_PER_PURCHASE = 25 * 10 ** 6 * 10 ** 18;
    // Maximum number of addresses: 2000
    uint256 public constant MAX_PURCHASES = 2000;

    // USDT contract address on Ethereum mainnet
    address public constant usdtAddress =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // Burn address for tokens
    address public blackHole = address(0);
    // Transfer fee percentage for buy/sell (2%)
    uint256 public constant TRANSFER_FEE_PERCENT = 2;

    // Mapping to track addresses that have participated in the sale
    mapping(address => bool) public hasPurchased;
    // Mapping to track liquidity pool addresses
    mapping(address => bool) public isLiquidityPool;
    // Counter for number of addresses that have participated in the sale
    uint256 public purchases = 0;
    // Flag to indicate if liquidity pool has been added
    bool public isLPAdded = false;
    // Flag to control whether transfers between users are enabled
    bool public transfersEnabled = false;

    // Events
    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 usdtSpent
    );
    event LPAdded(address lpAddress);
    event TransfersEnabled(bool enabled);

    constructor() ERC20("$guigui", "$GUI") Ownable(msg.sender) {
        _mint(address(this), TOTAL_SUPPLY);
    }

    /**
     * @dev Adds a Uniswap V3 liquidity pool address
     * @param _lpAddress The address of the Uniswap V3 pool to add
     */
    function addLP(address _lpAddress) external onlyOwner {
        require(!isLPAdded, "LP already added");
        isLiquidityPool[_lpAddress] = true;
        isLPAdded = true;
        emit LPAdded(_lpAddress);
    }

    /**
     * @dev Enables transfers after LP is added
     */
    function enableTransfers() external onlyOwner {
        require(isLPAdded, "Must add LP first");
        transfersEnabled = true;
        emit TransfersEnabled(true);
    }

    /**
     * @dev Purchase tokens in private sale
     * Requirements:
     * - Must send exactly 59 USDT
     * - Address can only purchase once
     * - Maximum 2000 addresses
     */
    function purchaseTokens() external {
        require(purchases < MAX_PURCHASES, "All allocations sold out");
        require(!hasPurchased[msg.sender], "Address has already purchased");

        // Transfer exactly 59 USDT from buyer
        IERC20(usdtAddress).safeTransferFrom(
            msg.sender,
            address(this),
            SALE_PRICE
        );

        hasPurchased[msg.sender] = true;
        purchases += 1;
        _transfer(address(this), msg.sender, TOKENS_PER_PURCHASE);
        emit TokensPurchased(msg.sender, TOKENS_PER_PURCHASE, SALE_PRICE);
    }

    /**
     * @dev Withdraw collected USDT from sales
     */
    function withdrawUSDT() external onlyOwner {
        uint256 usdtBalance = IERC20(usdtAddress).balanceOf(address(this));
        IERC20(usdtAddress).safeTransfer(owner(), usdtBalance);
    }

    /**
     * @dev Override of the _update function to implement:
     * 1. Transfer control before LP
     * 2. 2% burn on DEX trades (buy/sell)
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Allow minting and burning
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Allow contract operations (private sale)
        if (from == address(this) || to == address(this)) {
            super._update(from, to, amount);
            return;
        }

        // Handle DEX trades with 2% burn
        if (isLiquidityPool[from] || isLiquidityPool[to]) {
            uint256 burnAmount = (amount * TRANSFER_FEE_PERCENT) / 100;
            uint256 sendAmount = amount - burnAmount;

            if (burnAmount > 0) {
                super._update(from, blackHole, burnAmount);
            }
            super._update(from, to, sendAmount);
            return;
        }

        // Regular transfers between users
        require(transfersEnabled, "Transfers are not enabled yet");
        super._update(from, to, amount);
    }

    /**
     * @dev Renounce ownership, setting it to zero address.
     * Warning: Once ownership is renounced, the contract can no longer be controlled.
     * Requirements:
     * - Can only be called by the current owner
     */
    function renounceOwnership() public override onlyOwner {
        _transferOwnership(address(0));
        emit OwnershipTransferred(owner(), address(0));
    }

    /**
     * @dev Transfer contract ownership to a new address.
     * @param newOwner The address of the new owner
     * Requirements:
     * - Can only be called by the current owner
     * - newOwner cannot be zero address
     * - newOwner cannot be the current owner
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != owner(), "New owner cannot be current owner");
        _transferOwnership(newOwner);
        emit OwnershipTransferred(owner(), newOwner);
    }
}