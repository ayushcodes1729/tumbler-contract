// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./vault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GameContract {
    Vault public vault;
    address public treasury;
    uint256 public capacity;
    uint256 public currentFill;
    address public lastDepositor;

    uint256 public feeBps = 500; // 5%

    address public token; // MON token
    address public player1;
    address public player2;
    address public currentTurn; // whose turn it is

    event Deposit(address indexed player, string asset, uint256 amount, uint256 fill);
    event Overflow(address indexed loser, address indexed winner, uint256 prizeETH, uint256 prizeMON, uint256 feeETH, uint256 feeMON);

    constructor(address _vault, address _treasury, uint256 _capacity, address _token, address _player1, address _player2) {
        vault = Vault(payable(_vault));
        treasury = _treasury;
        capacity = _capacity;
        token = _token;
        player1 = _player1;
        player2 = _player2;
        currentTurn = player1;
    }

    modifier onlyCurrentTurn() {
        require(msg.sender == currentTurn, "Not your turn");
        _;
    }

    function depositETH() external payable onlyCurrentTurn {
        require(msg.value > 0, "Must deposit > 0");
        require(currentFill < capacity, "Game ended");

        vault.depositETH{value: msg.value}();
        currentFill += msg.value;

        _postDeposit(msg.sender, "ETH", msg.value);
    }

    function depositMON(uint256 amount) external onlyCurrentTurn {
        require(amount > 0, "Must deposit > 0");
        require(currentFill < capacity, "Game ended");

        IERC20(token).transferFrom(msg.sender, address(vault), amount); // deposit MON directly into vault
        currentFill += amount;

        _postDeposit(msg.sender, "MON", amount);
    }

    function _postDeposit(address depositor, string memory asset, uint256 amount) internal {
        if (currentFill > capacity) {
            _handleOverflow(depositor);
        } else {
            lastDepositor = depositor;
            emit Deposit(depositor, asset, amount, currentFill);
            _switchTurn();
        }
    }

    function _handleOverflow(address loser) internal {
        address winner = lastDepositor;

        uint256 vaultETH = address(vault).balance;
        uint256 vaultMON = IERC20(token).balanceOf(address(vault));

        uint256 feeETH = (vaultETH * feeBps) / 10000;
        uint256 feeMON = (vaultMON * feeBps) / 10000;

        uint256 prizeETH = vaultETH - feeETH;
        uint256 prizeMON = vaultMON - feeMON;

        if (vaultETH > 0) {
            vault.withdrawETH(treasury, feeETH);
            vault.withdrawETH(winner, prizeETH);
        }

        if (vaultMON > 0) {
            vault.withdrawERC20(token, treasury, feeMON);
            vault.withdrawERC20(token, winner, prizeMON);
        }

        // Reset
        currentFill = 0;
        lastDepositor = address(0);
        currentTurn = player1;

        emit Overflow(loser, winner, prizeETH, prizeMON, feeETH, feeMON);
    }

    function _switchTurn() internal {
        currentTurn = (currentTurn == player1) ? player2 : player1;
    }
}
