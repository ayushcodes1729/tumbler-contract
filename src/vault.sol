// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    // Withdraw ETH
    function withdrawETH(address to, uint256 amount) external onlyGame {
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    // Deposit ERC20 tokens
    function depositERC20(address token, uint256 amount) external onlyGame {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "ERC20 deposit failed");
    }

    // Withdraw ERC20 tokens
    function withdrawERC20(address token, address to, uint256 amount) external onlyGame {
        require(IERC20(token).transfer(to, amount), "ERC20 withdraw failed");
    }

    receive() external payable {}
}
