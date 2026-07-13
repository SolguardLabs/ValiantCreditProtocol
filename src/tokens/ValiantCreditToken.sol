// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";

contract ValiantCreditToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    address public immutable market;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    modifier onlyMarket() {
        require(msg.sender == market, "ONLY_MARKET");
        _;
    }

    constructor(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals, address tokenMarket) {
        require(tokenMarket != address(0), "MARKET_ZERO");
        name = tokenName;
        symbol = tokenSymbol;
        decimals = tokenDecimals;
        market = tokenMarket;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "ALLOWANCE");
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    function mint(address to, uint256 value) external onlyMarket {
        require(to != address(0), "TO_ZERO");
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function burn(address from, uint256 value) external onlyMarket {
        require(balanceOf[from] >= value, "BALANCE");
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function marketTransfer(address from, address to, uint256 value) external onlyMarket {
        _transfer(from, to, value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "TO_ZERO");
        require(balanceOf[from] >= value, "BALANCE");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
