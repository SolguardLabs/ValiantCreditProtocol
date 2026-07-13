// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library PercentageMath {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant HALF_BPS = 5_000;

    function percentMul(uint256 value, uint256 bps) internal pure returns (uint256) {
        if (value == 0 || bps == 0) return 0;
        return (value * bps) / BPS;
    }

    function percentMulUp(uint256 value, uint256 bps) internal pure returns (uint256) {
        if (value == 0 || bps == 0) return 0;
        return ((value * bps) - 1) / BPS + 1;
    }

    function percentDiv(uint256 value, uint256 bps) internal pure returns (uint256) {
        require(bps != 0, "PERCENT_DIV_ZERO");
        return (value * BPS) / bps;
    }

    function complement(uint256 bps) internal pure returns (uint256) {
        require(bps <= BPS, "BPS_TOO_HIGH");
        return BPS - bps;
    }

    function addBps(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c <= BPS, "BPS_TOO_HIGH");
        return c;
    }

    function validBps(uint256 bps) internal pure returns (bool) {
        return bps <= BPS;
    }
}
