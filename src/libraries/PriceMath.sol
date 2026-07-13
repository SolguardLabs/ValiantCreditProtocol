// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {WadMath} from "./WadMath.sol";

library PriceMath {
    using WadMath for uint256;

    function valueOf(uint256 amount, uint256 price, uint8 priceDecimals) internal pure returns (uint256) {
        if (amount == 0 || price == 0) return 0;
        return (amount * price) / (10 ** priceDecimals);
    }

    function amountForValue(uint256 value, uint256 price, uint8 priceDecimals) internal pure returns (uint256) {
        require(price != 0, "PRICE_ZERO");
        if (value == 0) return 0;
        return (value * (10 ** priceDecimals)) / price;
    }

    function amountForValueUp(uint256 value, uint256 price, uint8 priceDecimals) internal pure returns (uint256) {
        require(price != 0, "PRICE_ZERO");
        if (value == 0) return 0;
        return ((value * (10 ** priceDecimals)) - 1) / price + 1;
    }

    function normalizePrice(uint256 price, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) return price;
        if (fromDecimals < toDecimals) return price * (10 ** (toDecimals - fromDecimals));
        return price / (10 ** (fromDecimals - toDecimals));
    }

    function weightedAverage(uint256 priceA, uint256 weightA, uint256 priceB, uint256 weightB)
        internal
        pure
        returns (uint256)
    {
        uint256 weight = weightA + weightB;
        if (weight == 0) return 0;
        return ((priceA * weightA) + (priceB * weightB)) / weight;
    }

    function bounded(uint256 price, uint256 lower, uint256 upper) internal pure returns (uint256) {
        require(lower <= upper, "BOUNDS");
        if (price < lower) return lower;
        if (price > upper) return upper;
        return price;
    }

    function deviationBps(uint256 current, uint256 referencePrice) internal pure returns (uint256) {
        if (referencePrice == 0) return current == 0 ? 0 : type(uint256).max;
        uint256 diff = current > referencePrice ? current - referencePrice : referencePrice - current;
        return (diff * 10_000) / referencePrice;
    }

    function applyHaircut(uint256 price, uint256 haircutBps) internal pure returns (uint256) {
        require(haircutBps <= 10_000, "HAIRCUT");
        return (price * (10_000 - haircutBps)) / 10_000;
    }

    function applyPremium(uint256 price, uint256 premiumBps) internal pure returns (uint256) {
        return (price * (10_000 + premiumBps)) / 10_000;
    }
}
