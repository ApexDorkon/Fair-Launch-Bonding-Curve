// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWMOCA {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

/**
 * @title FairLaunchCurve
 * @notice Implements a mathematical bonding curve for fair token launches.
 * Price increases quadratically as the circulating supply sold increases.
 */
contract FairLaunchCurve is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20  public immutable token;
    IWMOCA  public immutable wmoca;
    address public immutable vaultReceiver;
    address public immutable oracle;

    bool public saleStarted;
    bool public finalized;

    uint256 public initialTokens; 
    uint256 public constant TARGET_GOAL = 10 ether; // Total MOCA to graduate
    uint16  public graduationThreshold = 9000;    // 90.00% completion

    event SaleStarted(uint256 totalTokens, uint16 threshold);
    event TokenPurchase(address indexed buyer, uint256 mocaIn, uint256 tokensOut);
    event TokenSale(address indexed seller, uint256 tokensIn, uint256 mocaOut);
    event LaunchFinalized(uint256 totalLiquidityGraduated);

    constructor(address _token, address _wmoca, address _vaultReceiver, address _oracle) {
        token = IERC20(_token);
        wmoca = IWMOCA(_wmoca);
        vaultReceiver = _vaultReceiver;
        oracle = _oracle;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Oracle Only");
        _;
    }

    // --- State Views ---

    function tokensSold() public view returns (uint256) {
        return saleStarted ? (initialTokens - token.balanceOf(address(this))) : 0;
    }

    function getProgressBps() public view returns (uint16) {
        if (!saleStarted || initialTokens == 0) return 0;
        return uint16((tokensSold() * 10000) / initialTokens);
    }

    /**
     * @dev Calculates the amount of tokens out for a given MOCA input using the integral of the curve.
     */
    function calculateBuy(uint256 mocaIn) public view returns (uint256 tokensOut) {
        uint256 sold = tokensSold();
        uint256 t2 = sqrt(sold * sold + (mocaIn * (initialTokens ** 2)) / TARGET_GOAL);
        tokensOut = t2 - sold;
        if (tokensOut > token.balanceOf(address(this))) tokensOut = token.balanceOf(address(this));
    }

    // --- Trading Functions ---

    function buy(uint256 minTokensOut) external payable nonReentrant whenNotPaused {
        require(saleStarted && !finalized, "Launch Inactive");
        require(msg.value > 0, "Zero Input");

        uint256 tokensOut = calculateBuy(msg.value);
        require(tokensOut >= minTokensOut, "Slippage Too High");

        wmoca.deposit{value: msg.value}();
        token.safeTransfer(msg.sender, tokensOut);

        emit TokenPurchase(msg.sender, msg.value, tokensOut);

        if (getProgressBps() >= graduationThreshold) _finalize();
    }

    function sell(uint256 tokensIn, uint256 minMocaOut) external nonReentrant whenNotPaused {
        require(saleStarted && !finalized, "Launch Inactive");
        
        uint256 sold = tokensSold();
        uint256 t2 = sold - tokensIn;
        uint256 mocaOut = (TARGET_GOAL * (sold * sold - t2 * t2)) / (initialTokens * initialTokens);
        require(mocaOut >= minMocaOut, "Slippage Too High");

        token.safeTransferFrom(msg.sender, address(this), tokensIn);
        wmoca.withdraw(mocaOut);
        
        (bool ok,) = payable(msg.sender).call{value: mocaOut}("");
        require(ok, "Transfer Failed");

        emit TokenSale(msg.sender, tokensIn, mocaOut);
    }

    // --- Lifecycle ---

    function startSale(uint16 _threshold) external onlyOracle {
        require(!saleStarted, "Already Started");
        initialTokens = token.balanceOf(address(this));
        require(initialTokens > 0, "Empty Reserve");
        graduationThreshold = _threshold;
        saleStarted = true;
        emit SaleStarted(initialTokens, _threshold);
    }

    function _finalize() internal {
        finalized = true;
        uint256 balance = wmoca.balanceOf(address(this));
        if (balance > 0) wmoca.transfer(vaultReceiver, balance);
        emit LaunchFinalized(balance);
        _pause();
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) { z = x; x = (y / x + x) / 2; }
        } else if (y != 0) { z = 1; }
    }

    receive() external payable {}
}