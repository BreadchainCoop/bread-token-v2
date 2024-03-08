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
    address public constant randomHolder = 0x23b4f73FB31e89B27De17f9c5DE2660cc1FB0CdF; // random multisig
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
        breadToken.setYieldClaimer(address(this));
        sexyDai = IERC20(0xaf204776c7245bF4147c2612BF6e5972Ee483701);
        wxDai = IERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        vm.roll(32661486);
        /// @dev we mint one BREAD and burn it to simulate what we'll do in reality
        /// this helps us avoid inflation attacks and underflow issues if burn totalSupply() in some cases
        breadToken.mint{value: 1 ether}(0x0000000000000000000000000000000000000001);
        vm.roll(32661487);
    }

    function test_basic_deposits() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));
        uint256 contractBalBefore = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyBefore, 1 ether);
        assertEq(balBefore, 0);
        assertGt(contractBalBefore, 0);
        assertLt(contractBalBefore, 1 ether);

        breadToken.mint{value: 1 ether}(address(this));

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertEq(balAfter, balBefore + 1 ether);
        assertGt(contractBalAfter, contractBalBefore);
        assertLt(contractBalAfter, supplyBefore + 1 ether);

        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        contractBalBefore = contractBalAfter;
        supplyBefore = supplyAfter;
        balBefore = balAfter;

        uint256 randomHolderBalBefore = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalBefore, 0);

        breadToken.mint{value: 5 ether}(randomHolder);

        supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, supplyBefore + 5 ether);
        balAfter = breadToken.balanceOf(address(this));
        assertEq(balAfter, balBefore);
        contractBalAfter = sexyDai.balanceOf(address(breadToken));
        assertGt(contractBalAfter, contractBalBefore);
        assertLt(contractBalAfter, supplyBefore + 5 ether);

        uint256 randomHolderBalAfter = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalAfter, 5 ether);

        uint256 randomHolderWXDAI = wxDai.balanceOf(randomHolder);
        assertGt(randomHolderWXDAI, 10000 ether);

        vm.roll(32661488);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661489);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);
    }

    function test_basic_withdraws() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));

        assertEq(supplyBefore, 1 ether);
        assertEq(balBefore, 0);

        breadToken.mint{value: 1 ether}(address(this));

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertEq(balAfter, balBefore + 1 ether);
        assertGt(contractBalAfter, 0);
        assertLt(contractBalAfter, supplyAfter);

        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        vm.roll(32661490);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661491);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);
    }

    function test_burn() public {
        vm.roll(326615001);
        uint256 checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 0);
        vm.deal(randomHolder, 1 ether);
        vm.prank(randomHolder);
        breadToken.mint{value: 1 ether}(randomHolder);
        checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 1);
        vm.roll(326615002);
        vm.prank(randomHolder);
        breadToken.burn(1 ether, randomHolder);
        checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 2);
        vm.roll(326615003);
        vm.deal(address(this), 2 ether);
        uint256 balBefore = address(this).balance;
        breadToken.mint{value:1 ether}(address(this));
        assertEq(address(this).balance, balBefore - 1 ether);
        balBefore = address(this).balance;
        uint256 supplyBefore = breadToken.totalSupply();
        vm.roll(326615004);
        breadToken.burn(0.5 ether, address(this));
        uint256 supplyAfter = breadToken.totalSupply();
        assertEq(balBefore + 0.5 ether, address(this).balance);
        assertEq(supplyAfter, supplyBefore - 0.5 ether);
    }

    function test_yield() public {
        vm.roll(32661496);
        uint256 supplyBefore = breadToken.totalSupply();
        assertEq(supplyBefore, 1 ether);
        uint256 yieldBefore = breadToken.yieldAccrued();

        breadToken.mint{value: 1 ether}(address(this));
        uint256 supplyAfter = breadToken.totalSupply();
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertGt(contractBalAfter, 0);


        yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        vm.roll(32661497);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661498);
        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);

     
    }
    function test_burn_steal() public{
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));

        assertEq(supplyBefore, 1 ether);
        assertEq(balBefore, 0);
        vm.roll(32661496);

        breadToken.mint{value: 1 ether}(address(this));
        vm.roll(32661497);

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertEq(balAfter, balBefore + 1 ether);
        assertGt(contractBalAfter, 0);
        assertLt(contractBalAfter, supplyAfter);

        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        vm.roll(32661497);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661498);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);

        balBefore = address(this).balance;
        breadToken.burn(0.5 ether, address(this));
        assertEq(balBefore + 0.5 ether, address(this).balance);
        vm.roll(32661499);

        supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, 1.5 ether);

        // balBefore = address(this).balance;
        // uint256 randHolderBalBefore = address(randomEOA).balance;
        // breadToken.burn(0.5 ether, address(randomEOA));
        // assertEq(balBefore, address(this).balance);
        // assertEq(randHolderBalBefore + 0.5 ether, address(randomEOA).balance);
        // supplyAfter = breadToken.totalSupply();
        // assertEq(supplyAfter, 1 ether);
        vm.roll(32661500);

        /// @dev NOTE we are "stealing" some wei from the yield when we mint and burn
        /// since sxDAI can round down by 1 wei -- this should be fine, 
        /// we just need to claim a little less than the total yield on claims
        /// and burn e.g 1 BREAD after deployment so that no user runs into burn revert
        /// (since no one can burn the last wei of the supply, which can trigger it)
        yieldBefore = yieldAfter;
        yieldAfter = breadToken.yieldAccrued();
        assertEq(yieldBefore - 1, yieldAfter);

    }

    receive() external payable {}
}
