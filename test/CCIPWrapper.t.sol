// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CCIPWrapper} from "../src/CCIPWrapper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Client} from "@chainlink/contracts-ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract CCIPWrapperTest is Test {
    CCIPWrapper public ccipWrapper;
    ZCHF public zCHF;
    SVZCHF public svZCHF;
    address public router = address(this);

    function setUp() public {
        zCHF = new ZCHF();
        svZCHF = new SVZCHF(zCHF, "svZCHF", "svZCHF");

        ccipWrapper = new CCIPWrapper(
            ERC4626(address(svZCHF)),
            IERC20(address(zCHF)),
            router
        );
    }

    function test_wrap() public {
        uint256 amount = 1000 * 10 ** zCHF.decimals();
        address recipient = address(0x456);

        // Mint zCHF to the wrapper contract
        zCHF.mint(address(ccipWrapper), amount);

        // Prepare the Any2EVMMessage
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(zCHF),
            amount: amount
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: 0,
            data: abi.encode(recipient),
            sender: abi.encode(address(this)),
            destTokenAmounts: tokenAmounts
        });

        // Call _ccipReceive directly for testing
        ccipWrapper.ccipReceive(message);

        // Check that the recipient received svZCHF
        uint256 svZCHFBalance = svZCHF.balanceOf(recipient);
        assertEq(svZCHFBalance, amount);
    }

    function test_reject_invalid_router() public {
        uint256 amount = 1000 * 10 ** zCHF.decimals();
        address recipient = address(0x456);

        // Mint zCHF to the wrapper contract
        zCHF.mint(address(ccipWrapper), amount);

        // Prepare the Any2EVMMessage
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(zCHF),
            amount: amount
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: 0,
            data: abi.encode(recipient),
            sender: abi.encode(address(this)),
            destTokenAmounts: tokenAmounts
        });

        // Call _ccipReceive directly for testing
        vm.prank(address(0x456));
        vm.expectRevert();
        ccipWrapper.ccipReceive(message);
    }

    function test_invalid_token_count() public {
        uint256 amount = 1000 * 10 ** zCHF.decimals();
        address recipient = address(0x456);

        // Mint zCHF to the wrapper contract
        zCHF.mint(address(ccipWrapper), amount);

        // Prepare the Any2EVMMessage with invalid token count
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](2);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(zCHF),
            amount: amount
        });
        tokenAmounts[1] = Client.EVMTokenAmount({
            token: address(zCHF),
            amount: amount
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: 0,
            data: abi.encode(recipient),
            sender: abi.encode(address(this)),
            destTokenAmounts: tokenAmounts
        });

        // Call _ccipReceive directly for testing
        vm.expectRevert(CCIPWrapper.InvalidTokenCount.selector);
        ccipWrapper.ccipReceive(message);
    }

    function test_invalid_token() public {
        uint256 amount = 1000 * 10 ** zCHF.decimals();
        address recipient = address(0x456);

        // Mint zCHF to the wrapper contract
        zCHF.mint(address(ccipWrapper), amount);

        // Prepare the Any2EVMMessage with invalid token
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(0x789), // Invalid token
            amount: amount
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: 0,
            data: abi.encode(recipient),
            sender: abi.encode(address(this)),
            destTokenAmounts: tokenAmounts
        });

        // Call _ccipReceive directly for testing
        vm.expectRevert(CCIPWrapper.InvalidToken.selector);
        ccipWrapper.ccipReceive(message);
    }
}

contract ZCHF is ERC20 {
    constructor() ERC20("zCHF", "zCHF") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SVZCHF is ERC4626 {
    constructor(
        ERC20 asset,
        string memory name,
        string memory symbol
    ) ERC4626(asset) ERC20(name, symbol) {}
}
