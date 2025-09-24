// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Vault {
    address public game;

    modifier onlyGame() {
        require(msg.sender == game, "Not authorized");
        _;
    }

    constructor(address _game) {
        game = _game;
    }

    // Accept ETH deposits from Game
    function depositETH() external payable onlyGame {}

    // Withdraw ETH to a specific address (Game controls)
    function withdrawETH(address to, uint256 amount) external onlyGame {
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    receive() external payable {}
}
