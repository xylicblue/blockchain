// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CropEscrow.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock stablecoin for testing
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CropEscrowTest is Test {
    CropEscrow escrow;
    MockUSDT usdt;

    address admin = address(0x1);
    address oracle = address(0x2);
    address investor = address(0x3);
    address farmer = address(0x4);

    bytes32 milestoneId1 = keccak256("milestone_1");

    function setUp() public {
        vm.startPrank(admin);
        
        usdt = new MockUSDT();
        escrow = new CropEscrow(address(usdt));
        
        // Grant Oracle role
        escrow.grantRole(escrow.ORACLE_ROLE(), oracle);
        
        vm.stopPrank();

        // Give investor some mock USDT and approve escrow
        usdt.mint(investor, 1000 * 10**18);
        vm.prank(investor);
        usdt.approve(address(escrow), 1000 * 10**18);
    }

    function testDeposit() public {
        vm.prank(investor);
        escrow.deposit(milestoneId1, farmer, 500 * 10**18);

        (address f, address i, uint256 a, bool funded, bool released) = escrow.milestones(milestoneId1);
        
        assertEq(f, farmer);
        assertEq(i, investor);
        assertEq(a, 500 * 10**18);
        assertTrue(funded);
        assertFalse(released);
        
        assertEq(usdt.balanceOf(address(escrow)), 500 * 10**18);
    }

    function testReleasePayment() public {
        vm.prank(investor);
        escrow.deposit(milestoneId1, farmer, 500 * 10**18);

        // Advance verification status
        vm.prank(oracle);
        escrow.releasePayment(milestoneId1);

        (, , , , bool released) = escrow.milestones(milestoneId1);
        assertTrue(released);

        assertEq(usdt.balanceOf(farmer), 500 * 10**18);
        assertEq(usdt.balanceOf(address(escrow)), 0);
    }

    function testReleasePaymentUnauthorized() public {
        vm.prank(investor);
        escrow.deposit(milestoneId1, farmer, 500 * 10**18);

        vm.prank(investor);
        vm.expectRevert();
        escrow.releasePayment(milestoneId1);
    }

    function testRefund() public {
        vm.prank(investor);
        escrow.deposit(milestoneId1, farmer, 500 * 10**18);

        vm.prank(admin);
        escrow.refund(milestoneId1);

        assertEq(usdt.balanceOf(investor), 1000 * 10**18);
        assertEq(usdt.balanceOf(address(escrow)), 0);
    }
}
