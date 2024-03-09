// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Bread - An ERC20 stablecoin fully collateralized by Gnosis Chain xDAI
// which earns yield via Gnosis Chain sDAI (aka sexyDAI)
// and points this yield to the Breadchain Ecosystem
// implemented by: kassandra.eth

import {
    SafeERC20,
    IERC20
} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    OwnableUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {
    ERC20VotesUpgradeable
}
from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {ISXDAI} from "./interfaces/ISXDAI.sol";

contract Bread is
    ERC20VotesUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;
    
    address public yieldClaimer;
    error MintZero();
    error BurnZero();
    error ClaimZero();
    error YieldInsufficient();
    error IsCollateral();
    error NativeTransferFailed();
    error OnlyClaimers();
    error MismatchArray();
    error MismatchAmount();

    IWXDAI public immutable wxDai;
    ISXDAI public immutable sexyDai;

    event Minted(address receiver, uint256 amount);
    event Burned(address receiver, uint256 amount);
    event YieldClaimerSet(address yieldClaimer);
    event ClaimedYield(uint256 amount);

    constructor(
        address _wxDai,
        address _sexyDai
    ) {
        wxDai = IWXDAI(_wxDai);
        sexyDai = ISXDAI(_sexyDai);
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address owner_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
    }

    function setYieldClaimer(address _yieldClaimer) external onlyOwner {
        yieldClaimer = _yieldClaimer;
        emit YieldClaimerSet(_yieldClaimer);
    }

    function mint(address receiver) external payable {
        uint256 val = msg.value;
        if (val == 0) revert MintZero();

        wxDai.deposit{value: val}();
        IERC20(address(wxDai)).safeIncreaseAllowance(address(sexyDai), val);
        sexyDai.deposit(val, address(this));

        _mint(receiver, val);
        _delegate(receiver, receiver);
    }

    function batchMint( uint256[] calldata amounts,address[] calldata receivers) external payable {
        uint256 val = msg.value;
        if (val == 0) revert MintZero();
        if (receivers.length != amounts.length) revert MismatchArray();

        wxDai.deposit{value: val}();
        IERC20(address(wxDai)).safeIncreaseAllowance(address(sexyDai), val);
        sexyDai.deposit(val, address(this));
        uint256 amountsTotal; 
        for (uint256 i = 0; i < receivers.length; i++) {
            if (amounts[i] == 0) revert MintZero();
            amountsTotal += amounts[i];
            _mint(receivers[i], amounts[i]);
            _delegate(receivers[i], receivers[i]);
        }
        if (amountsTotal != val) revert MismatchAmount();
    }

    function burn(uint256 amount, address receiver) external {
        if (amount == 0) revert BurnZero();
        _burn(msg.sender, amount);
        
        sexyDai.withdraw(amount, address(this), address(this));
        wxDai.withdraw(amount);
        _nativeTransfer(receiver, amount);

        emit Burned(receiver, amount);
    }

    function claimYield(uint256 amount, address receiver) external {
        if (msg.sender != owner() || msg.sender != yieldClaimer) revert OnlyClaimers();
        if (amount == 0) revert ClaimZero();
        uint256 yield = _yieldAccrued();
        if (yield < amount) revert YieldInsufficient();

        _mint(receiver, amount);
        _delegate(receiver, receiver);

        emit ClaimedYield(amount);
    }

    function rescueToken(address tok, uint256 amount) external onlyOwner {
        if (tok == address(sexyDai)) revert IsCollateral();
        IERC20(tok).safeTransfer(owner(), amount);
    }

    function yieldAccrued() external view returns (uint256) {
        return _yieldAccrued();
    }

    function _yieldAccrued() internal view returns (uint256) {
        uint256 bal = IERC20(address(sexyDai)).balanceOf(address(this));
        uint256 assets = sexyDai.convertToAssets(bal);
        uint256 supply = totalSupply();
        return assets > supply ? assets - supply : 0;
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
