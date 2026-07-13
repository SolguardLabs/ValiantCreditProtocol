// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library WadMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    function mulWad(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x == 0 || y == 0) return 0;
        return (x * y) / WAD;
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x == 0 || y == 0) return 0;
        return ((x * y) - 1) / WAD + 1;
    }

    function divWad(uint256 x, uint256 y) internal pure returns (uint256) {
        require(y != 0, "WAD_DIV_ZERO");
        return (x * WAD) / y;
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        require(y != 0, "WAD_DIV_ZERO");
        if (x == 0) return 0;
        return ((x * WAD) - 1) / y + 1;
    }

    function powWad(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : WAD;
        for (n /= 2; n != 0; n /= 2) {
            x = mulWad(x, x);
            if (n % 2 != 0) z = mulWad(z, x);
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? x : y;
    }

    function clamp(uint256 x, uint256 low, uint256 high) internal pure returns (uint256) {
        if (x < low) return low;
        if (x > high) return high;
        return x;
    }

    function absDiff(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? x - y : y - x;
    }

    function avg(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x & y) + ((x ^ y) >> 1);
    }

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        uint256 y = x;
        z = 1;
        if (y >= 0x100000000000000000000000000000000) {
            y >>= 128;
            z <<= 64;
        }
        if (y >= 0x10000000000000000) {
            y >>= 64;
            z <<= 32;
        }
        if (y >= 0x100000000) {
            y >>= 32;
            z <<= 16;
        }
        if (y >= 0x10000) {
            y >>= 16;
            z <<= 8;
        }
        if (y >= 0x100) {
            y >>= 8;
            z <<= 4;
        }
        if (y >= 0x10) {
            y >>= 4;
            z <<= 2;
        }
        if (y >= 0x8) z <<= 1;
        z = (z + x / z) >> 1;
        z = (z + x / z) >> 1;
        z = (z + x / z) >> 1;
        z = (z + x / z) >> 1;
        z = (z + x / z) >> 1;
        z = (z + x / z) >> 1;
        z = (z + x / z) >> 1;
        uint256 roundedDown = x / z;
        return z < roundedDown ? z : roundedDown;
    }

    function toWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * (10 ** (18 - decimals));
        return amount / (10 ** (decimals - 18));
    }

    function fromWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount / (10 ** (18 - decimals));
        return amount * (10 ** (decimals - 18));
    }
}
