// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./FairLaunchCurve.sol";

/**
 * @title TokenLaunchFactory
 * @dev Deploys and tracks individual FairLaunchCurve instances for new tokens.
 * This is the entry point for the "Pump.fun" style ecosystem.
 */
contract TokenLaunchFactory {
    event CurveDeployed(address indexed token, address indexed curve, uint256 timestamp);

    struct LaunchInfo {
        address token;
        address curve;
        uint256 createdAt;
    }

    address public immutable wmoca;
    address public immutable vaultReceiver;
    address public immutable oracle;
    address public owner;

    LaunchInfo[] public allLaunches;
    mapping(address => address) public tokenToCurve;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Authorized");
        _;
    }

    constructor(address _wmoca, address _vaultReceiver, address _oracle) {
        require(_wmoca != address(0) && _vaultReceiver != address(0) && _oracle != address(0), "Zero Address");
        wmoca = _wmoca;
        vaultReceiver = _vaultReceiver;
        oracle = _oracle;
        owner = msg.sender;
    }

    function deployLaunchCurve(address token, bool autoStart) external onlyOwner returns (address curveAddr) {
        require(token != address(0), "Invalid Token");
        require(tokenToCurve[token] == address(0), "Launch Already Exists");

        // Deploy new Fair Launch Curve
        FairLaunchCurve curve = new FairLaunchCurve(token, wmoca, vaultReceiver, oracle);
        curveAddr = address(curve);

        tokenToCurve[token] = curveAddr;
        allLaunches.push(LaunchInfo({
            token: token,
            curve: curveAddr,
            createdAt: block.timestamp
        }));

        emit CurveDeployed(token, curveAddr, block.timestamp);

        if (autoStart) {
            try curve.startSale(9000) {} catch {}
        }
    }

    function getLaunchCount() external view returns (uint256) {
        return allLaunches.length;
    }
}