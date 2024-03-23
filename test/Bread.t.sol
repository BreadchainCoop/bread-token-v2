// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Bread} from "../src/Bread.sol";
import {EIP173ProxyWithReceive} from "../src/proxy/EIP173ProxyWithReceive.sol";
import {IERC20} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract BreadTest is Test {
    EIP173ProxyWithReceive public breadProxy;
    Bread public breadToken;
    IERC20 public sexyDai;
    IERC20 public wxDai;
    address public constant randomHolder =
        0x23b4f73FB31e89B27De17f9c5DE2660cc1FB0CdF; // random multisig
    address public constant randomEOA =
        0x4B5BaD436CcA8df3bD39A095b84991fAc9A226F1;
    address[] receivers;
    uint256[] amounts;
    address[] migration_addresses;
    uint256[] migration_amounts;

    function setUp() public {
        address breadImpl = address(
            new Bread(
                0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d,
                0xaf204776c7245bF4147c2612BF6e5972Ee483701
            )
        );

        breadProxy = new EIP173ProxyWithReceive(
            breadImpl,
            address(this),
            bytes("")
        );

        breadToken = Bread(address(breadProxy));

        breadToken.initialize("Breadchain Stablecoin", "BREAD", address(this));
        breadToken.setYieldClaimer(address(this));
        sexyDai = IERC20(0xaf204776c7245bF4147c2612BF6e5972Ee483701);
        wxDai = IERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        vm.roll(32661486);
        /// @dev we mint one BREAD and burn it to simulate what we'll do in reality
        /// this helps us avoid inflation attacks and underflow issues if burn totalSupply() in some cases
        breadToken.mint{value: 1 ether}(
            0x0000000000000000000000000000000000000001
        );
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
        breadToken.mint{value: 1 ether}(address(this));
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

        vm.roll(32661499);
        breadToken.setYieldClaimer(randomHolder);
        vm.roll(32661500);
        vm.prank(randomHolder);
        breadToken.claimYield(1, randomHolder);
        // uint256 bal = breadToken.balanceOf(address(this));
        // assertEq(bal, 1);
        // vm.roll(32661501);
        // vm.prank(randomEOA);
        // vm.expectRevert();
        // breadToken.claimYield(1 ether, randomEOA);
    }

    function testBatchMint() public {
        receivers.push(address(0x42));
        amounts.push(1 ether);

        // Expect no revert
        vm.expectRevert();
        breadToken.batchMint(amounts, receivers);

        receivers.push(address(0x43)); // Adding an extra receiver to cause mismatch
        vm.expectRevert();
        breadToken.batchMint{value: 1 ether}(amounts, receivers);
        amounts.push(0 ether);
        vm.expectRevert();
        breadToken.batchMint{value: 2 ether}(amounts, receivers);
        amounts.pop();
        amounts.pop();
        amounts.push(1 ether);
        amounts.push(1 ether);
        uint256 balbeforeAdr1 = breadToken.balanceOf(address(0x42));
        uint256 balbeforeAdr2 = breadToken.balanceOf(address(0x43));
        assertEq(balbeforeAdr1, 0);
        assertEq(balbeforeAdr2, 0);
        breadToken.batchMint{value: 2 ether}(amounts, receivers);
        uint256 balAfterAdr1 = breadToken.balanceOf(address(0x42));
        uint256 balAfterAdr2 = breadToken.balanceOf(address(0x43));
        assertEq(balAfterAdr1, 1 ether);
        assertEq(balAfterAdr2, 1 ether);
    }

    function testFuzzyBatchMint(uint256 seed, uint256 numReceivers) public {
        // Fuzzing with constraints
        vm.assume(numReceivers > 0 && numReceivers <= 10); // Limit the number of receivers to a reasonable range

        uint256 totalMintAmount = 0;
        address[] memory _receivers = new address[](numReceivers);
        uint256[] memory _amounts = new uint256[](numReceivers);

        for (uint256 i = 0; i < numReceivers; i++) {
            // Generate a pseudo-random address based on the seed and index
            address receiver = address(
                uint160(uint256(keccak256(abi.encode(seed, i))))
            );
            uint256 amount = ((seed % 10) + 1) * 0.1 ether; // Amounts between 0.1 ether and 1 ether

            _receivers[i] = receiver;
            _amounts[i] = amount;
            totalMintAmount += amount;
        }

        vm.deal(address(breadToken), totalMintAmount); // Ensure the contract has enough ether for minting
        breadToken.batchMint{value: totalMintAmount}(_amounts, _receivers); // Mint with the generated values

        // Verifying the results
        for (uint256 i = 0; i < numReceivers; i++) {
            uint256 receiverBalance = breadToken.balanceOf(_receivers[i]);
            assertEq(
                receiverBalance,
                _amounts[i],
                "Balance mismatch after batch mint"
            );
        }

        uint256 totalSupplyAfter = breadToken.totalSupply();
        assertEq(
            totalSupplyAfter,
            totalMintAmount + 1 ether,
            "Total supply should increase by the total mint amount"
        );
    }
    function test_transfer_from() public {
        breadToken.mint{value: 1 ether}(address(this));
        breadToken.approve(address(0x42), 1 ether);
        vm.prank(address(0x42));
        breadToken.transferFrom(address(this), address(0x42), 1 ether);
        uint256 bal = breadToken.balanceOf(address(0x42));
        assertEq(bal, 1 ether);
    }
    function test_allowance() public {
        breadToken.mint{value: 1 ether}(address(this));
        breadToken.approve(address(0x42), 1 ether);
        uint256 allowance = breadToken.allowance(address(this), address(0x42));
        assertEq(allowance, 1 ether);
        vm.prank(address(0x42));
        breadToken.transferFrom(address(this), address(0x42), 1 ether);
    }
    function test_migration() public {
        uint256 polygontotalSupply = 39791324311589626057102;
        migration_addresses = [
            0x1d60C34f508BbBd7f1cb50b375c4CdD25e718D1c,
            0xA91f80c61D863b2b5924989c6fb9d12b43Ea7609,
            0x36116eb544a38DE052e260d8f1ebc8600c1dB77e,
            0x778549Eb292AC98A96a05E122967f22eFA003707,
            0xE885626097850EC1C5759d4bC8718C8762c68077,
            0x5c26df05610Cc00C3B5979B39701Ae2cd1f72064,
            0xaE7f11378dABA3757e9D7691be04285938bE35B5,
            0xb8645966716C2A2aDE6922531f4AFA02a919251c,
            0xdE2BE7C9C542c55a7a77489A3A7745493988947F,
            0x5Cad04c369C90F48eBa73342810258C1F24fbe79,
            0xc053d2877C03e7FB96D6D29cE2d557c886f700A6,
            0xb3A5cfb7776A4e11fE570C3698837D5b2217Ad00,
            0x7a738EfFD10bF108b7617Ec8E96a0722fa54C547,
            0xC8ec0Fa33C777C26E6C7fb8874C41CB2b8aFf8FA,
            0xaECD6D9172d602b93dBA3981991268b44af8096e,
            0xC69E8318eA6406a248af54dbf0893E0f4CAa946B,
            0xc474A87d0a27f09b490CB660df1623afA1b3B8A8,
            0x3d9456Ad6463a77bD77123Cb4836e463030bfAb4,
            0xD9C4475E2dd89a9a0aD0C1E9a1e1bb28Df7BA298,
            0x036e3972F2b499699414Fe9476D496ca2F8C824B,
            0x601729aCddB9E966822A90DE235d494647691F1d,
            0x4171160dB0e7E2C75A4973b7523B437C010Dd9d4,
            0x50cCa5ed8B4455fbe316785269FC82500b67fD48,
            0xD30F2888E7928b52EA5bF4cb1D323e0531aFe272,
            0x36C6361D625E83084a767d6A275500F6901BDeff,
            0x18A725aD96aE6a8b6e8DbE3FB3a8eb042e2F8879,
            0x4CabDdC93479241224d874553611D170AdBf8C71,
            0x88215a2794ddC031439C72922EC8983bDE831c78,
            0x252B2948E6001595Eda3B61c821B479F3CeAfB12,
            0x4A1a9bAC59491Bbcb04A53D879D9D9a81E6C3605,
            0xc70c7f140d095381bFe45C9de8F16F7548547832,
            0x64c4a97D92fBa5396Df4d3512a27097389325480,
            0x40498d7936B8d07B5f72d642C531bD76F76f812F,
            0xc873ff31b7594F3BEc714F68D1C4bD0221bD4126,
            0x6375885ce997543CC7e057fE9aF3E255D52Fb4f4,
            0x2fD39e6741b1446C51e8A120aB1D69F645e10e0E,
            0x6c85e0c9D254EC60CcC88B2Cb0f275289e194aB9,
            0xA7CcccaB83529c4898349f58D9dca352f0E3Db3F,
            0x486D8f9cb85B447E897666ad2afb279C7e18A9B5,
            0x933f30Cf206C68E27a879DdC9E9d0b97D95f299A,
            0x618d36795ec3cEd056d4595144Ff64bF832cD8b9,
            0xf6f32d231b517D32b98Ce03464C2A7c272BdB272,
            0x7BB8C33e8C3D36127Ae5f9B81C61c721fBdF9a6b,
            0x7E3991C83DA05C44E49C0665fE571C5ABacee8c7,
            0x5f90D8B4918741119362446Ffe48B576F8F7faef,
            0x35A807F9dD68C7B03A992477F85cF5a08Ee9a69e,
            0xDfB0b22940Cc45283D639D22ba26aa55ab8Bfee8,
            0xbDBcB6f07ccCC22A05f841B2eE9A1468FA840E17,
            0xDfedCa937Db08c9149534854BBBba3051f96D1b1,
            0x156A0d0CAaE8dAEe1c0b5Bc6b8285fC168BEf26F,
            0xF439B8e757dbFbed6a0C3089ab916c3fd01DDA78,
            0xBA333F8ff556bF35D38E102a98dAF1c5F6d9D708,
            0x9a18F460e29d552F9C8a6F5e834c92c9E9dF9b86,
            0x94E19509E2E4eaa2058ADDfc660D677F6A8EfD27,
            0x66a1e1772b53895C8C4eDcACF2ebBC10f8EA0F57,
            0xd87cfD8757DB0Aa5b3380bC8009881f64f76Bd20,
            0xd5BaB90d59f6E5f10C4059D9806fcA1BB132b022,
            0x534Bb03DB5D6D896113965D44b51eAcC978cFfC2,
            0x499109Cbd554E4AD63a03CF79E171b0d5A347A1b,
            0x504E7620069a0a8354434dED3150ed7E2ECF5153,
            0x5d3216aFeefEF0a5C51494d27992E146b5186EDB,
            0x530cd668C4a93a30C3453135525Af9e118125495,
            0x1AD43538F303a03d4CF0Be10bd408a23E8bdF73F,
            0xC304Eef1023e0b6e644f8ED8f8c629fD0973c52d,
            0xbeD089F9eB43A799479C73c65712b01511Bf8da6,
            0x3d909b6cB958a32f1A6e0D016C387A3a2C8DeCd1,
            0x62552bD69BA53CA51F3450D803Fb00e0D71db40d,
            0x888586aF168f2cdC9D557a823Bd33BadD7CeD0ca,
            0x8e3FA59FbB152A2833B4f66757f2cf63Da2254aF,
            0x2440B90e1f840F5426057fcCF1A78afEbBAf7f96,
            0xAf5F0b98fad3905b16140CB879a9c8df217B362C,
            0x854a4AF0044c1952776e05474aa85D4636d75910,
            0x819B2886Cb636db6098e6f0E52aa6A30B5cFf1bB,
            0xFa1093e2bacCa0b148284be2F650B5E00F83B72f,
            0xE73a198e7C07c418D7dcFd42f5E953074aBbD125,
            0x8E2549F104e1bDb9C940cca71daB57359FE08Bb8,
            0x72E1638bD8cD371Bfb04cF665b749A0E4ae38324,
            0x19Ad09F76a0B1d7b29e606504AC3b46F0414654E,
            0x59DDA36bD196Ec849838CE2163E6821f946b37Dc,
            0x4C0a466DF0628FE8699051b3Ac6506653191cc21,
            0x7d878CE75fe153C84dC3E25D1Fcb54C7932dc4Bf,
            0xF8D1d34956cEa24718cf8687588D6FeDbc6d9AA6,
            0x961FdC36F035Ee426bAa3362924a3939c94e1562,
            0x5CC2eC9378e4fD3e5B91a6FA338EDcC8edd36FF8,
            0xEb4E3e9fA819E69e5Df4ea35b9C7973062C96de9,
            0x2F4BcD8AdBE961290f2c4df752852466e7D655c9,
            0x21f638773A6646730b2648faEF2C95389032c6A7,
            0x6002cA2e11B8e8c0F1F09c67F551B209eb51A0E4,
            0x2e33f5c128F85295219eA63624baf82e25d0EA51,
            0xfF8592A0e6acF8975b5b9B6643eB20aD2550CA89,
            0x06B0380925f18C0C9f2cc5200217DF9a81E805f2,
            0xf3B06b503652a5E075D423F97056DFde0C4b066F,
            0xB5129C0EF9D65d432e4f245513D3C1276e090347,
            0x6795DA7baFB1595DfaB3764D943Ecdded97Ea88b,
            0x7B2e78D4dFaABA045A167a70dA285E30E8FcA196,
            0xf780eE9f9e50248E7F8433a132a4b0b00B3dA313,
            0x5f8b9B4541Ecef965424f1dB923806aAD626Add2,
            0x6A148b997e6651237F2fCfc9E30330a6480519f0,
            0x3f6e4f79F35Dc8D21D492C60DaF9f55AA902d618,
            0x3055C602454ddE1BDa3e98B1bCfD2Ed68ab9789E,
            0xE952e16A4b0BA8Ee6e40002517705895d6BcAc40,
            0xE41D784991067704186984Ed06d8e04bd5aD0fc2,
            0x6f565161198235f3299F8cBF4C2c6D4E819f5DE9,
            0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE,
            0x753317bC1ca91F8a12aad7fe78f09DEB0397212e,
            0x00696aFD9bB2A552f54cC9A68BE38b7809B70252,
            0xf6fA97A91e3d190e067846269aaAdECBC9A8C87a,
            0x33aC9CAE1Cd9CBB191116607f564F7381d81BAD9,
            0x918dEf5d593F46735f74F9E2B280Fe51AF3A99ad
        ];
        migration_amounts= [
            1000000000000000000,
            2000000000000000000,
            1049434170000000000,
            10500000000000000000,
            1130000000000000000000,
            15000000000000000000,
            10000000000000000000,
            20006179874752062588,
            14875001945965136852,
            111000000000000000000,
            369509441283556208281,
            10000000000000000000,
            70000000000000000000,
            210000000000000000000,
            10000000000000000000,
            10000000000000000000,
            85000000000000000000,
            10000000000000000000,
            10000000000000000000,
            10000000000000000000,
            10000000000000000000,
            10000000000000000000,
            10500000000000000000,
            40000000000000000000,
            500000000000000000000,
            5103553222935547,
            300000000000000000000,
            1000000000000000000,
            10536699826174859678,
            20000000000000000000,
            10000000000000000000,
            15000000000000000000,
            10500000000000000000,
            49526000000000000000,
            100000000000000000000,
            999758363687661493842,
            95000000000000000000,
            10000000000000000000,
            1300000000000000000,
            20000000000000000000,
            100000000000000000000,
            377379625237371992,
            10530515618992923096,
            10000000000000000000,
            15000000000000000000,
            10991627315958077337,
            145000000000000000000,
            12431646314320140932,
            1000000000000000000,
            600000000000000000000,
            90000000000000000000,
            10000000000000000000,
            50000000000000000000,
            65000000000000000000,
            25000000000000000000,
            74991872265556673834,
            2687001846091446,
            5298983838010000,
            10000000000000000000,
            10000000000000000000,
            15000000000000000000,
            10000000000000000000,
            20001000050000000000,
            21000000000000000000,
            50000000000000000000,
            20000000000000000000,
            17000000000000000000,
            1005216355662533665,
            1110069562590244408,
            50000000000000000000,
            50000000000000000000,
            6000000000000000000,
            40000000000000000000,
            20000000000000000000,
            2000000000000000000,
            5560000000000000000,
            6999999998499474000,
            3000000001500526000,
            20000000000000000000,
            69078875220932980185,
            10000000000000000000,
            2176175970114874216,
            9732031901839308852,
            12416479916753708,
            710455193108857,
            15000000000000000000,
            5000000000000000000,
            14990000000000000000,
            4561076106274262739985,
            350000000000000000000,
            500000000000000000000,
            30000000000000000000,
            500000000000000000,
            99823105817665230801,
            4000000000000000000,
            50000000000000000000,
            50500000000000000000,
            4523967209611154265025,
            331314182184129242087,
            695590009403958563,
            11000000000000000000,
            136700000000000000000,
            1,
            9999000000000000000,
            9800999999999999999,
            1000000000000000000,
            2238541110297335924,
            500000000000000000,
            23070145829119381495401
        ];
        breadToken.batchMint{value:polygontotalSupply}(migration_amounts, migration_addresses);
        assertEq(breadToken.totalSupply(), polygontotalSupply + 1 ether);
    }

    receive() external payable {}
}
