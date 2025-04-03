// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployMyToken} from "../script/DeployMyToken.s.sol";
import {MyToken} from "src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public myToken;
    DeployMyToken public deployer;
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    address bob = makeAddr("bob");
    address alice = makeAddr("Alice");
    address deployer_address;

    // Events to test
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        // Get the deployer's address
        address tokenDeployer = vm.addr(1);
        // Set the deployer as the active sender
        vm.startPrank(tokenDeployer);

        // Deploy the token manually instead of using the script
        myToken = new MyToken(INITIAL_SUPPLY);

        // Transfer to bob from the deployer account
        myToken.transfer(bob, STARTING_BALANCE);

        vm.stopPrank();

        // Store the deployer address for later checks
        deployer_address = tokenDeployer;
    }

    // Test initial token metadata
    function testTokenMetadata() public {
        assertEq(myToken.name(), "MyToken");
        assertEq(myToken.symbol(), "MTK");
        assertEq(myToken.decimals(), 18);
    }

    // Test initial supply was correctly minted to deployer
    function testInitialSupply() public {
        assertEq(myToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(myToken.balanceOf(deployer_address), INITIAL_SUPPLY - STARTING_BALANCE);
    }

    // Test balance after initial transfer
    function testBobBalance() public {
        assertEq(STARTING_BALANCE, myToken.balanceOf(bob));
    }

    // Test direct transfers
    function testTransfer() public {
        uint256 transferAmount = 10 ether;

        // Starting balances
        uint256 bobStartingBalance = myToken.balanceOf(bob);
        uint256 aliceStartingBalance = myToken.balanceOf(alice);

        // Transfer from bob to alice
        vm.prank(bob);

        // Test emit event
        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, transferAmount);

        bool success = myToken.transfer(alice, transferAmount);

        // Verify transfer was successful
        assertTrue(success);
        assertEq(myToken.balanceOf(bob), bobStartingBalance - transferAmount);
        assertEq(myToken.balanceOf(alice), aliceStartingBalance + transferAmount);
    }

    // Test insufficient balance reverts
    function test_RevertWhen_InsufficientBalance() public {
        uint256 bobBalance = myToken.balanceOf(bob);

        vm.prank(bob);
        vm.expectRevert();
        myToken.transfer(alice, bobBalance + 1);
    }

    // Test approve function
    function testApprove() public {
        uint256 approveAmount = 1000;

        vm.prank(bob);

        // Test emit event
        vm.expectEmit(true, true, false, true);
        emit Approval(bob, alice, approveAmount);

        bool success = myToken.approve(alice, approveAmount);

        assertTrue(success);
        assertEq(myToken.allowance(bob, alice), approveAmount);
    }

    // Test allowances and transferFrom
    function testAllowancesAndTransferFrom() public {
        uint256 initialAllowance = 1000;

        vm.prank(bob);
        myToken.approve(alice, initialAllowance);

        uint256 transferAmount = 500;

        vm.prank(alice);

        // Test emit event for transferFrom
        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, transferAmount);

        bool success = myToken.transferFrom(bob, alice, transferAmount);

        assertTrue(success);
        assertEq(myToken.balanceOf(alice), transferAmount);
        assertEq(myToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        // Check that allowance was decreased
        assertEq(myToken.allowance(bob, alice), initialAllowance - transferAmount);
    }

    // Test insufficient allowance reverts
    function test_RevertWhen_InsufficientAllowance() public {
        uint256 initialAllowance = 100;

        vm.prank(bob);
        myToken.approve(alice, initialAllowance);

        uint256 transferAmount = initialAllowance + 1;

        vm.prank(alice);
        vm.expectRevert();
        myToken.transferFrom(bob, alice, transferAmount);
    }

    // Test approving and updating allowances
    function testUpdateAllowance() public {
        uint256 initialAllowance = 100;
        uint256 newAllowance = 200;

        vm.startPrank(bob);
        myToken.approve(alice, initialAllowance);
        assertEq(myToken.allowance(bob, alice), initialAllowance);

        // Test emit event for new approval
        vm.expectEmit(true, true, false, true);
        emit Approval(bob, alice, newAllowance);

        bool success = myToken.approve(alice, newAllowance);
        vm.stopPrank();

        assertTrue(success);
        assertEq(myToken.allowance(bob, alice), newAllowance);
    }

    // Test zero address transfers revert
    function test_RevertWhen_TransferToZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert();
        myToken.transfer(address(0), 10);
    }

    function test_RevertWhen_TransferFromToZeroAddress() public {
        vm.prank(bob);
        myToken.approve(alice, 100);

        vm.prank(alice);
        vm.expectRevert();
        myToken.transferFrom(bob, address(0), 10);
    }

    // Test approve to zero address
    function test_RevertWhen_ApproveZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert();
        myToken.approve(address(0), 100);
    }

    // Test burn scenario (self-transfer to zero address should fail per ERC20)
    function test_RevertWhen_BurnAttempt() public {
        vm.prank(bob);
        vm.expectRevert();
        myToken.transfer(address(0), 10);
    }
}
