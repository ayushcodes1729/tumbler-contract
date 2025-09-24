// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./vault.sol";

contract GameContract {
    Vault public vault;
    address public treasury;
    uint256 public capacity;
    uint256 public currentFill;
    address public lastDepositor;

    uint256 public feeBps = 500; // 5%

    event Deposit(address indexed player, uint256 amount, uint256 fill);
    event Overflow(address indexed loser, address indexed winner, uint256 prize, uint256 fee);
    constructor(address _vault, address _treasury, uint256 _capacity) {
        vault = Vault(payable(_vault));
        treasury = _treasury;
        capacity = _capacity;
        currentFill = 0;
    }

    function depositETH() external payable {
        require(msg.value > 0, "Must deposit > 0");
        require(currentFill < capacity, "Game ended");

        // send deposit to vault
        vault.depositETH{value: msg.value}();
        currentFill += msg.value;

        if (currentFill > capacity) {
            _handleOverflow(msg.sender);
        } else {
            lastDepositor = msg.sender;
            emit Deposit(msg.sender, msg.value, currentFill);
        }
    }

    function _handleOverflow(address loser) internal {
        address winner = lastDepositor;
        uint256 totalPot = address(vault).balance;

        uint256 fee = (totalPot * feeBps) / 10000;
        uint256 prize = totalPot - fee;

        // Vault sends ETH to treasury & winner
        vault.withdrawETH(treasury, fee);
        vault.withdrawETH(winner, prize);

        // Reset game
        currentFill = 0;
        lastDepositor = address(0);

        emit Overflow(loser, winner, prize, fee);
    }
}
