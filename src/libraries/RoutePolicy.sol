// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PercentageMath} from "./PercentageMath.sol";

library RoutePolicy {
    using PercentageMath for uint256;

    enum RouteStatus {
        None,
        Open,
        Matured,
        Frozen,
        Closed
    }

    struct Policy {
        uint64 openedAt;
        uint64 maturity;
        uint64 cooldown;
        uint64 frozenAt;
        uint256 principal;
        uint256 debt;
        uint256 maxUtilizationBps;
        RouteStatus status;
    }

    function isOpen(Policy memory policy) internal view returns (bool) {
        if (policy.status != RouteStatus.Open) return false;
        if (policy.maturity != 0 && block.timestamp > policy.maturity) return false;
        return true;
    }

    function canIncrease(Policy memory policy, uint256 lineLimit, uint256 amount) internal view returns (bool) {
        if (!isOpen(policy)) return false;
        if (lineLimit == 0) return false;
        uint256 projected = policy.principal + amount;
        return projected.percentDiv(lineLimit) <= policy.maxUtilizationBps;
    }

    function canClose(Policy memory policy) internal view returns (bool) {
        if (policy.status == RouteStatus.Closed || policy.status == RouteStatus.None) return false;
        if (policy.cooldown == 0) return true;
        return block.timestamp >= uint256(policy.openedAt) + policy.cooldown;
    }

    function statusAt(Policy memory policy) internal view returns (RouteStatus) {
        if (policy.status == RouteStatus.None || policy.status == RouteStatus.Closed) return policy.status;
        if (policy.status == RouteStatus.Frozen) return RouteStatus.Frozen;
        if (policy.maturity != 0 && block.timestamp > policy.maturity) return RouteStatus.Matured;
        return RouteStatus.Open;
    }

    function withDebt(Policy memory policy, uint256 debt) internal pure returns (Policy memory) {
        policy.debt = debt;
        if (debt == 0 && policy.principal == 0) policy.status = RouteStatus.Closed;
        return policy;
    }

    function withPrincipal(Policy memory policy, uint256 principal) internal pure returns (Policy memory) {
        policy.principal = principal;
        if (principal == 0 && policy.debt == 0) policy.status = RouteStatus.Closed;
        return policy;
    }

    function freeze(Policy memory policy) internal view returns (Policy memory) {
        require(policy.status == RouteStatus.Open, "NOT_OPEN");
        policy.status = RouteStatus.Frozen;
        policy.frozenAt = uint64(block.timestamp);
        return policy;
    }

    function utilizationBps(Policy memory policy, uint256 lineLimit) internal pure returns (uint256) {
        if (lineLimit == 0) return 0;
        return policy.principal.percentDiv(lineLimit);
    }
}
