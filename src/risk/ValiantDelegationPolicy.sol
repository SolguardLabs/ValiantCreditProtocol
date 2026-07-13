// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PercentageMath} from "../libraries/PercentageMath.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantDelegationPolicy {
    using PercentageMath for uint256;

    struct ScoreInput {
        uint256 sponsorCollateral;
        uint256 sponsorDebt;
        uint256 requestedLimit;
        uint256 delegateOpenDebt;
        uint256 delegateRepayVolume30d;
        uint256 delegateDefaults;
        uint256 marketUtilizationBps;
    }

    struct ScoreResult {
        uint256 recommendedLimit;
        uint256 utilizationBps;
        uint256 concentrationBps;
        uint256 reliabilityBps;
        bool withinPolicy;
    }

    uint256 public constant MAX_DEFAULT_PENALTY_BPS = 7_500;
    uint256 public constant MIN_RELIABILITY_BPS = 2_500;

    function directRemaining(ValiantTypes.LineSnapshot memory line) external pure returns (uint256) {
        if (!line.active || line.limit <= line.used) return 0;
        return line.limit - line.used;
    }

    function managedRemaining(ValiantTypes.ManagedLineSnapshot memory line) external pure returns (uint256) {
        if (!line.active || line.limit <= line.used) return 0;
        return line.limit - line.used;
    }

    function utilization(uint256 used, uint256 limit) public pure returns (uint256) {
        if (limit == 0) return 0;
        return used.percentDiv(limit);
    }

    function lineHealthy(uint256 used, uint256 limit, uint256 maxUtilizationBps) external pure returns (bool) {
        if (limit == 0) return used == 0;
        return utilization(used, limit) <= maxUtilizationBps;
    }

    function score(ScoreInput calldata input) external pure returns (ScoreResult memory result) {
        uint256 availableCollateral = input.sponsorCollateral > input.sponsorDebt
            ? input.sponsorCollateral - input.sponsorDebt
            : 0;
        uint256 baseline = availableCollateral.percentMul(7_500);
        uint256 concentration = input.requestedLimit == 0 || baseline == 0 ? 0 : input.requestedLimit.percentDiv(baseline);
        uint256 reliability = _reliability(input.delegateRepayVolume30d, input.delegateDefaults);
        uint256 utilizationBps = input.marketUtilizationBps;
        uint256 utilizationHaircut = utilizationBps > 8_000 ? 5_000 : utilizationBps > 6_000 ? 2_500 : 0;
        uint256 reliabilityHaircut = PercentageMath.BPS - reliability;
        uint256 haircut = utilizationHaircut + reliabilityHaircut;
        if (haircut > 9_000) haircut = 9_000;
        result.recommendedLimit = baseline.percentMul(PercentageMath.BPS - haircut);
        result.utilizationBps = utilizationBps;
        result.concentrationBps = concentration;
        result.reliabilityBps = reliability;
        result.withinPolicy = input.requestedLimit <= result.recommendedLimit && reliability >= MIN_RELIABILITY_BPS;
    }

    function maxChildLimit(uint256 parentRemaining, uint256 managerOutstanding, uint256 concentrationBps)
        external
        pure
        returns (uint256)
    {
        require(concentrationBps <= PercentageMath.BPS, "CONCENTRATION");
        uint256 adjusted = parentRemaining.percentMul(concentrationBps);
        if (managerOutstanding >= adjusted) return 0;
        return adjusted - managerOutstanding;
    }

    function expiryWithinPolicy(uint64 expiresAt, uint256 maxTenor) external view returns (bool) {
        if (expiresAt == 0) return maxTenor == 0;
        if (expiresAt <= block.timestamp) return false;
        if (maxTenor == 0) return true;
        return expiresAt <= block.timestamp + maxTenor;
    }

    function _reliability(uint256 repayVolume, uint256 defaults) internal pure returns (uint256) {
        if (defaults == 0) return PercentageMath.BPS;
        uint256 penalty = defaults * 1_500;
        if (repayVolume > 0) {
            uint256 volumeOffset = repayVolume > 1_000_000e18 ? 3_000 : repayVolume > 100_000e18 ? 1_500 : 500;
            penalty = penalty > volumeOffset ? penalty - volumeOffset : 0;
        }
        if (penalty > MAX_DEFAULT_PENALTY_BPS) penalty = MAX_DEFAULT_PENALTY_BPS;
        return PercentageMath.BPS - penalty;
    }
}
