// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VaultTest is Test {
    Vault vault;
    MockToken token;
    address game = address(0x123);
    address alice = address(0xabc);
    address bob = address(0xdef);

    function setUp() public {
        token = new MockToken();
        vault = new Vault(game);
    }

    // -------------------
    // ETH DEPOSIT / WITHDRAW
    // -------------------

    function testDepositETHOnlyGame() public {
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert("Not authorized");
        vault.depositETH{value: 1 ether}();

        vm.deal(game, 1 ether);
        vm.prank(game);
        vault.depositETH{value: 1 ether}();
        assertEq(address(vault).balance, 1 ether);
    }

    function testWithdrawETHOnlyGame() public {
        // Seed vault with ETH
        vm.deal(game, 2 ether);
        vm.prank(game);
        vault.depositETH{value: 2 ether}();

        // Not game -> revert
        vm.prank(alice);
        vm.expectRevert("Not authorized");
        vault.withdrawETH(bob, 1 ether);

        // Game can withdraw
        vm.prank(game);
        vault.withdrawETH(bob, 1 ether);
        assertEq(bob.balance, 1 ether);
    }

    // -------------------
    // ERC20 DEPOSIT / WITHDRAW
    // -------------------

    function testDepositERC20OnlyGame() public {
        token.mint(game, 100 ether);

        // Non-game should fail
        vm.prank(alice);
        vm.expectRevert("Not authorized");
        vault.depositERC20(address(token), 1 ether);

        // Game approves and deposits
        vm.startPrank(game);
        token.approve(address(vault), 50 ether);
        vault.depositERC20(address(token), 50 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), 50 ether);
    }

    function testWithdrawERC20OnlyGame() public {
        token.mint(game, 100 ether);

        // Game deposits tokens
        vm.startPrank(game);
        token.approve(address(vault), 100 ether);
        vault.depositERC20(address(token), 100 ether);
        vm.stopPrank();

        // Non-game should fail
        vm.prank(alice);
        vm.expectRevert("Not authorized");
        vault.withdrawERC20(address(token), bob, 10 ether);

        // Game can withdraw
        vm.prank(game);
        vault.withdrawERC20(address(token), bob, 20 ether);

        assertEq(token.balanceOf(bob), 20 ether);
        assertEq(token.balanceOf(address(vault)), 80 ether);
    }
}
