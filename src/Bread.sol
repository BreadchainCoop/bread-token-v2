// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Bread - An ERC20 stablecoin fully collateralized by DAI
// which earns sDAI yeild on Gnosis Chain (aka sexyDAI) for the Breadchain Ecosystem
// implemented by: kassandra.eth

import {
    ERC20Upgradeable
} from "openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    OwnableUpgradeable
} from "openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Bread is
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    IWXDAI public immutable wxDai;
    ISXDAI public immutable sexyDai;

    event Minted(address receiver, uint256 amount);
    event Burned(address receiver, uint256 amount);

    event ClaimedYield(uint256 amount);
    event ClaimedRewards(address[] rewardsList, uint256[] claimedAmounts);

    constructor(
        address _wxDai,
        address _sexyDai
    ) {
        wxDai = IERC20(_wxDai);
        sexyDai = ISXDAI(_sexyDai);
    }

    function initialize(string memory name, string memory symbol) external initializer {
        __ERC20_init(name, symbol);
        __ReentrancyGuard_init();
        __Ownable_init();
    }

    function mint(uint256 amount, address receiver) external {
        require(amount > 0, "Bread: mint 0");
        IERC20 _token = token;
        IPool _pool = pool;
        _token.safeTransferFrom(msg.sender, address(this), amount);
        _token.safeIncreaseAllowance(address(_pool), amount);
        _pool.supply(address(_token), amount, address(this), 0);
        _mint(receiver, amount);
        emit Minted(receiver, amount);
    }

    function burn(uint256 amount, address receiver) external nonReentrant {
        require(amount > 0, "Bread: burn 0");
        _burn(msg.sender, amount);
        IPool _pool = pool;
        aToken.safeIncreaseAllowance(address(_pool), amount);
        _pool.withdraw(address(token), amount, receiver);
        emit Burned(receiver, amount);
    }

    function claimYield(uint256 amount) external nonReentrant {
        require(amount > 0, "Bread: claim 0");
        uint256 yield = _yieldAccrued();
        require(yield >= amount, "Bread: amount exceeds yield accrued");
        pool.withdraw(address(token), amount, owner());
        emit ClaimedYield(amount);
    }

    function rescueToken(address tok, uint256 amount) external onlyOwner {
        require(tok != address(aToken), "Bread: cannot withdraw collateral");
        IERC20(tok).safeTransfer(owner(), amount);
    }

    function yieldAccrued() external view returns (uint256) {
        return _yieldAccrued();
    }

    function rewardsAccrued()
        external
        view
        returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts)
    {
        address[] memory assets;
        assets[0] = address(aToken);
        return rewards.getAllUserRewards(assets, address(this));
    }

    function _yieldAccrued() internal view returns (uint256) {
        return aToken.balanceOf(address(this)) - totalSupply();
    }
}
