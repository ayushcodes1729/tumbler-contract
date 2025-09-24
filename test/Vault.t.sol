// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Vault} from "../src/vault.sol";

contract AcceptingReceiver {
    receive() external payable {}
}

contract RevertingReceiver {
    receive() external payable {
        revert("receive reverted");
    }
}

contract VaultTest is Test {
    Vault internal vault;
    address internal game;
    address internal alice;

    function setUp() public {
        game = address(0xAA11);
        alice = address(0xBEEF);
        vault = new Vault(game);

        // Fund key addresses
        vm.deal(game, 100 ether);
        vm.deal(alice, 100 ether);
    }

    function testConstructorSetsGame() public view {
        assertEq(vault.game(), game, "game not set correctly");
    }

    function testDepositETHOnlyGame() public {
        // Non-game cannot deposit
        vm.expectRevert(bytes("Not authorized"));
        vault.depositETH{value: 1 ether}();

        // Game can deposit
        vm.prank(game);
        vault.depositETH{value: 2 ether}();
        assertEq(address(vault).balance, 2 ether, "vault balance after deposit");
    }

    function testWithdrawETHOnlyGame() public {
        // Seed vault via game deposit
        vm.prank(game);
        vault.depositETH{value: 5 ether}();

        // Non-game cannot withdraw
        vm.expectRevert(bytes("Not authorized"));
        vault.withdrawETH(alice, 1 ether);

        // Game can withdraw
        uint256 aliceBefore = alice.balance;
        vm.prank(game);
        vault.withdrawETH(alice, 3 ether);
        assertEq(alice.balance, aliceBefore + 3 ether, "alice received ETH");
        assertEq(address(vault).balance, 2 ether, "vault decremented");
    }

    function testWithdrawRevertsOnInsufficientBalance() public {
        // Vault empty, attempt to withdraw should fail inside call
        vm.prank(game);
        vm.expectRevert(bytes("ETH transfer failed"));
        vault.withdrawETH(alice, 1 ether);
    }

    function testWithdrawRevertsWhenReceiverReverts() public {
        // Seed vault
        vm.prank(game);
        vault.depositETH{value: 1 ether}();

        // Receiver that reverts on receive
        RevertingReceiver receiver = new RevertingReceiver();

        vm.prank(game);
        vm.expectRevert(bytes("ETH transfer failed"));
        vault.withdrawETH(address(receiver), 1 ether);
    }

    function testReceiveDirectETH() public {
        // Send ETH directly to fallback/receive
        (bool ok, ) = address(vault).call{value: 1.5 ether}("");
        assertTrue(ok, "direct send failed");
        assertEq(address(vault).balance, 1.5 ether, "balance via receive");
    }
}


