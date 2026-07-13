// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValiantAccess} from "../access/ValiantAccess.sol";
import {IValiantRateModel} from "../interfaces/IValiantRateModel.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {WadMath} from "../libraries/WadMath.sol";

contract ValiantRateModel is ValiantAccess, IValiantRateModel {
    using PercentageMath for uint256;
    using WadMath for uint256;

    event ModelUpdated(uint256 baseRate, uint256 slopeOne, uint256 slopeTwo, uint256 kink);

    uint256 public baseRate;
    uint256 public slopeOne;
    uint256 public slopeTwo;
    uint256 public kink;

    constructor(address initialOwner, uint256 baseRate_, uint256 slopeOne_, uint256 slopeTwo_, uint256 kink_)
        ValiantAccess(initialOwner)
    {
        _setModel(baseRate_, slopeOne_, slopeTwo_, kink_);
    }

    function setModel(uint256 baseRate_, uint256 slopeOne_, uint256 slopeTwo_, uint256 kink_) external onlyRiskAdmin {
        _setModel(baseRate_, slopeOne_, slopeTwo_, kink_);
    }

    function utilization(uint256 cash, uint256 borrows, uint256 reserves) public pure returns (uint256) {
        if (borrows == 0) return 0;
        uint256 available = cash > reserves ? cash - reserves : 0;
        return borrows.divWad(available + borrows);
    }

    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view returns (uint256) {
        uint256 util = utilization(cash, borrows, reserves);
        if (util <= kink) {
            if (kink == 0) return baseRate + slopeOne;
            return baseRate + slopeOne.mulWad(util.divWad(kink));
        }
        uint256 normal = baseRate + slopeOne;
        uint256 excess = util - kink;
        uint256 remaining = WadMath.WAD - kink;
        if (remaining == 0) return normal + slopeTwo;
        return normal + slopeTwo.mulWad(excess.divWad(remaining));
    }

    function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactorBps)
        external
        view
        returns (uint256)
    {
        uint256 util = utilization(cash, borrows, reserves);
        uint256 borrowerRate = getBorrowRate(cash, borrows, reserves);
        uint256 retained = PercentageMath.complement(reserveFactorBps);
        return borrowerRate.mulWad(util).percentMul(retained);
    }

    function _setModel(uint256 baseRate_, uint256 slopeOne_, uint256 slopeTwo_, uint256 kink_) internal {
        require(kink_ <= WadMath.WAD, "KINK");
        baseRate = baseRate_;
        slopeOne = slopeOne_;
        slopeTwo = slopeTwo_;
        kink = kink_;
        emit ModelUpdated(baseRate_, slopeOne_, slopeTwo_, kink_);
    }
}
