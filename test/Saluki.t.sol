// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Saluki.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SalukiTest is Test {
    SalukiToken public token;
    address public owner;
    address public user1;
    address public user2;
    address public lpAddress;
    MockUSDT public usdt;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        lpAddress = makeAddr("lpAddress");

        // 首先部署合约
        token = new SalukiToken();

        // 部署模拟USDT到指定地址并给用户一些余额
        usdt = new MockUSDT();
        vm.mockCall(
            token.usdtAddress(),
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        vm.mockCall(
            token.usdtAddress(),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        // 给测试用户一些ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testInitialSupply() public view {
        token.totalSupply();
        token.balanceOf(address(token));
    }

    function testPurchaseTokens() public {
        vm.startPrank(user1);

        // Mock USDT approve
        vm.mockCall(
            token.usdtAddress(),
            abi.encodeWithSelector(
                IERC20.allowance.selector,
                user1,
                address(token)
            ),
            abi.encode(token.SALE_PRICE())
        );

        token.purchaseTokens();

        assertEq(token.balanceOf(user1), token.TOKENS_PER_PURCHASE());
        assertTrue(token.hasPurchased(user1));
        assertEq(token.purchases(), 1);
        vm.stopPrank();
    }

    function testCannotPurchaseTwice() public {
        vm.startPrank(user1);

        // Mock USDT approve for first purchase
        vm.mockCall(
            token.usdtAddress(),
            abi.encodeWithSelector(
                IERC20.allowance.selector,
                user1,
                address(token)
            ),
            abi.encode(token.SALE_PRICE())
        );

        token.purchaseTokens();

        // Try to purchase again
        vm.expectRevert("Address has already purchased");
        token.purchaseTokens();
        vm.stopPrank();
    }

    function testTransferWithLPBurn() public {
        // 设置LP并启用转账
        token.addLP(lpAddress);
        token.enableTransfers();

        uint256 amount = 1000 * 10 ** 18;

        // 从合约转移代币给user1
        vm.prank(address(token));
        token.transfer(user1, amount);

        // 确认user1收到了代币
        assertEq(token.balanceOf(user1), amount);

        // 记录初始总供应量
        uint256 initialSupply = token.totalSupply();

        // 测试与LP的交易会触发燃烧
        vm.startPrank(user1);

        // 计算预期的燃烧和转账金额
        uint256 burnAmount = (amount * token.TRANSFER_FEE_PERCENT()) / 100; // 2%
        uint256 expectedTransfer = amount - burnAmount;

        // 记录转账前的余额
        uint256 lpBalanceBefore = token.balanceOf(lpAddress);

        // 执行转账
        token.transfer(lpAddress, amount);

        // 验证LP地址收到的金额
        assertEq(
            token.balanceOf(lpAddress) - lpBalanceBefore,
            expectedTransfer,
            "LP balance incorrect"
        );

        // 验证总供应量减少了正确的燃烧数量
        assertEq(
            token.totalSupply(),
            initialSupply - burnAmount,
            "Total supply should decrease by burn amount"
        );

        // 验证user1的余额已经正确扣除
        assertEq(
            token.balanceOf(user1),
            0,
            "User balance should be 0 after transfer"
        );

        vm.stopPrank();
    }

    function testTransferBetweenUsersBeforeEnabled() public {
        // 先从合约转移代币给user1
        vm.prank(address(token));
        token.transfer(user1, 1000 * 10 ** 18);

        vm.startPrank(user1);
        vm.expectRevert("Transfers are not enabled yet");
        token.transfer(user2, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testAddLP() public {
        token.addLP(lpAddress);
        assertTrue(token.isLiquidityPool(lpAddress));
        assertTrue(token.isLPAdded());
    }

    function testCannotAddLPTwice() public {
        token.addLP(lpAddress);
        vm.expectRevert("LP already added");
        token.addLP(address(0x123));
    }

    function testEnableTransfers() public {
        token.addLP(lpAddress);
        token.enableTransfers();
        assertTrue(token.transfersEnabled());
    }

    function testCannotEnableTransfersBeforeLP() public {
        vm.expectRevert("Must add LP first");
        token.enableTransfers();
    }
}

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
