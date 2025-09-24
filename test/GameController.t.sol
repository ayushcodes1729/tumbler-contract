// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vault.sol";
import "../src/gameController.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MON") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract GameContractTest is Test {
    Vault vault;
    GameContract game;
    MockToken token;
    address treasury = address(0x1111);
    address player1 = address(0xAAAA);
    address player2 = address(0xBBBB);

    function setUp() public {
        vault = new Vault(address(this)); // deploy with placeholder game
        token = new MockToken();

        // deploy GameContract
        game = new GameContract(address(vault), treasury, 10 ether, address(token), player1, player2);

        // set vault's game address = game contract
        vm.store(
            address(vault),
            bytes32(uint256(0)), // slot 0 = game variable
            bytes32(uint256(uint160(address(game))))
        );

        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);

        token.transfer(player1, 500 ether);
        token.transfer(player2, 500 ether);

        vm.label(player1, "Player1");
        vm.label(player2, "Player2");
    }

    function testTurnOrder() public {
        vm.prank(player1);
        game.depositETH{value: 1 ether}();
        assertEq(address(vault).balance, 1 ether);
        assertEq(game.currentTurn(), player2);

        vm.prank(player2);
        game.depositETH{value: 2 ether}();
        assertEq(address(vault).balance, 3 ether);
        assertEq(game.currentTurn(), player1);
    }

    function testDepositMON() public {
        vm.startPrank(player1);
        token.approve(address(game), 10 ether);
        game.depositMON(10 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), 10 ether);
        assertEq(game.currentTurn(), player2);
    }

    function testOverflowETH() public {
        vm.prank(player1);
        game.depositETH{value: 6 ether}();

        vm.prank(player2);
        game.depositETH{value: 6 ether}();

        assertEq(address(vault).balance, 0, "vault should be empty");
        assertEq(player1.balance > player2.balance, true, "winner got prize");
        assertEq(treasury.balance > 0, true, "treasury got fee");
    }

    function testOverflowMON() public {
        vm.startPrank(player1);
        token.approve(address(game), 6 ether);
        game.depositMON(6 ether);
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(game), 6 ether);
        game.depositMON(6 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), 0, "vault MON should be empty");
        assertEq(token.balanceOf(player1) > token.balanceOf(player2), true, "winner got prize");
        assertEq(token.balanceOf(treasury) > 0, true, "treasury got fee");
    }

    function testNotYourTurnReverts() public {
        vm.prank(player2);
        vm.expectRevert("Not your turn");
        game.depositETH{value: 1 ether}();
    }
}
