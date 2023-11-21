// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Bread - An ERC20 stablecoin fully collateralized by DAI
// which earns sDAI yeild on Gnosis Chain (aka sexyDAI) for the Breadchain Ecosystem
// implemented by: kassandra.eth
import {SafeERC20, IERC20} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ERC20Upgradeable
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {
    OwnableUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {ISXDAI} from "./interfaces/ISXDAI.sol";

contract Bread is
    ERC20Upgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    error NativeTransferFailed();
    error MintZero();
    error BurnZero();

    IWXDAI public immutable wxDai;
    ISXDAI public immutable sexyDai;

    event Minted(address receiver, uint256 amount);
    event Burned(address receiver, uint256 amount);

    event ClaimedYield(uint256 amount);

    constructor(
        address _wxDai,
        address _sexyDai
    ) {
        wxDai = IWXDAI(_wxDai);
        sexyDai = ISXDAI(_sexyDai);
    }

    function initialize(string memory name_, string memory symbol_, address owner_) external initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
    }

    function mint(address receiver) external payable {
        uint256 val = msg.value;
        if (val == 0) revert MintZero();

        wxDai.deposit{value: val}();
        IERC20(address(wxDai)).safeIncreaseAllowance(address(sexyDai), val);
        sexyDai.deposit(val, address(this));

        _mint(receiver, val);
        emit Minted(receiver, val);
    }

    function burn(uint256 amount, address receiver) external {
        if (amount == 0) revert BurnZero();
        _burn(msg.sender, amount);

        sexyDai.withdraw(amount, address(this), address(this));
        wxDai.withdraw(amount);
        _nativeTransfer(receiver, amount);

        emit Burned(receiver, amount);
    }

    function claimYield(uint256 amount) external {
        require(amount > 0, "Bread: claim 0");
        uint256 yield = _yieldAccrued();
        require(yield >= amount, "Bread: amount exceeds yield accrued");
        sexyDai.withdraw(amount, owner(), address(this));
        emit ClaimedYield(amount);
    }

    function rescueToken(address tok, uint256 amount) external onlyOwner {
        require(tok != address(sexyDai), "Bread: cannot withdraw collateral");
        IERC20(tok).safeTransfer(owner(), amount);
    }

    function yieldAccrued() external view returns (uint256) {
        return _yieldAccrued();
    }

    function _yieldAccrued() internal view returns (uint256) {
        uint256 bal = IERC20(address(sexyDai)).balanceOf(address(this));
        return sexyDai.convertToAssets(bal) - totalSupply();
    }

    function _nativeTransfer(address to, uint256 amount) internal {
        bool success;
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        if (!success) revert NativeTransferFailed();
    }
}
