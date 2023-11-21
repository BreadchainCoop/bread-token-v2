// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Bread} from "../src/Bread.sol";
import {EIP173ProxyWithReceive} from "../src/proxy/EIP173ProxyWithReceive.sol";
import {
    IERC20
} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract BreadTest is Test {
    EIP173ProxyWithReceive public breadProxy;
    Bread public breadToken;
    IERC20 public sexyDai;
    IERC20 public wxDai;
    address public constant randomHolder = 0x01d9c9Ca040e90fEB47c7513d9A3574f6e1317bD;
    address public constant randomEOA = 0x4B5BaD436CcA8df3bD39A095b84991fAc9A226F1;

    function setUp() public {
        address breadImpl = address(new Bread(
            0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d,
            0xaf204776c7245bF4147c2612BF6e5972Ee483701
        ));

        breadProxy = new EIP173ProxyWithReceive(
            breadImpl,
            address(this),
            bytes("")
        );

        breadToken = Bread(address(breadProxy));

        breadToken.initialize(
            "Breadchain Stablecoin",
            "BREAD",
            address(this)
        );

        sexyDai = IERC20(0xaf204776c7245bF4147c2612BF6e5972Ee483701);
        wxDai = IERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
    }

    function test_basic_deposits() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));
        uint256 contractBalBefore = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyBefore, 0);
        assertEq(balBefore, 0);
        assertEq(contractBalBefore, 0);

        breadToken.mint{value: 1 ether}(address(this));

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, 1 ether);
        assertEq(balAfter, 1 ether);
        assertGt(contractBalAfter, 0);
        assertLt(contractBalAfter, 1 ether);

        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        contractBalBefore = contractBalAfter;

        uint256 randomHolderBalBefore = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalBefore, 0);

        breadToken.mint{value: 5 ether}(randomHolder);

        supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, 6 ether);
        balAfter = breadToken.balanceOf(address(this));
        assertEq(balAfter, 1 ether);
        contractBalAfter = sexyDai.balanceOf(address(breadToken));
        assertGt(contractBalAfter, contractBalBefore);
        assertLt(contractBalAfter, 6 ether);

        uint256 randomHolderBalAfter = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalAfter, 5 ether);

        uint256 randomHolderWXDAI = wxDai.balanceOf(randomHolder);
        assertGt(randomHolderWXDAI, 10000 ether);

        vm.roll(10);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(11);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);
    }

    function test_basic_withdraws() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));
        uint256 contractBalBefore = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyBefore, 0);
        assertEq(balBefore, 0);
        assertEq(contractBalBefore, 0);

        breadToken.mint{value: 1 ether}(address(this));

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, 1 ether);
        assertEq(balAfter, 1 ether);
        assertGt(contractBalAfter, 0);
        assertLt(contractBalAfter, 1 ether);

        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        vm.roll(10);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(11);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);

        balBefore = address(this).balance;
        breadToken.burn(0.5 ether, address(this));
        assertEq(balBefore + 0.5 ether - 1, address(this).balance);

        supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, 0.5 ether);

        balBefore = address(this).balance;
        uint256 randHolderBalBefore = address(randomEOA).balance;
        breadToken.burn(0.5 ether, address(randomEOA));
        assertEq(balBefore, address(this).balance);
        assertEq(randHolderBalBefore + 0.5 ether - 1, address(randomEOA).balance);
        supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, 0);

        yieldBefore = yieldAfter;
        yieldAfter = breadToken.yieldAccrued();
        assertEq(yieldAfter, yieldBefore);

        uint256 ownerBalBefore = wxDai.balanceOf(address(this));
        breadToken.claimYield(yieldAfter);
        assertEq(ownerBalBefore + yieldAfter, wxDai.balanceOf(address(this)));
    }

    receive() external payable {}
}
