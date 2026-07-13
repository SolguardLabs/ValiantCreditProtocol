// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PercentageMath} from "./PercentageMath.sol";

library ExposureMath {
    using PercentageMath for uint256;

    struct ExposureBucket {
        uint256 limit;
        uint256 used;
        uint256 pending;
        uint256 reserved;
    }

    function remaining(ExposureBucket memory bucket) internal pure returns (uint256) {
        uint256 consumed = bucket.used + bucket.pending + bucket.reserved;
        return consumed >= bucket.limit ? 0 : bucket.limit - consumed;
    }

    function utilizationBps(ExposureBucket memory bucket) internal pure returns (uint256) {
        if (bucket.limit == 0) return 0;
        uint256 consumed = bucket.used + bucket.pending + bucket.reserved;
        return consumed.percentDiv(bucket.limit);
    }

    function canConsume(ExposureBucket memory bucket, uint256 amount) internal pure returns (bool) {
        return remaining(bucket) >= amount;
    }

    function consume(ExposureBucket memory bucket, uint256 amount) internal pure returns (ExposureBucket memory) {
        require(canConsume(bucket, amount), "LIMIT");
        bucket.used += amount;
        return bucket;
    }

    function release(ExposureBucket memory bucket, uint256 amount) internal pure returns (ExposureBucket memory) {
        bucket.used = amount >= bucket.used ? 0 : bucket.used - amount;
        return bucket;
    }

    function reserve(ExposureBucket memory bucket, uint256 amount) internal pure returns (ExposureBucket memory) {
        require(remaining(bucket) >= amount, "RESERVE_LIMIT");
        bucket.reserved += amount;
        return bucket;
    }

    function settleReserved(ExposureBucket memory bucket, uint256 amount) internal pure returns (ExposureBucket memory) {
        require(bucket.reserved >= amount, "RESERVED");
        bucket.reserved -= amount;
        bucket.used += amount;
        return bucket;
    }

    function cancelReserved(ExposureBucket memory bucket, uint256 amount) internal pure returns (ExposureBucket memory) {
        require(bucket.reserved >= amount, "RESERVED");
        bucket.reserved -= amount;
        return bucket;
    }

    function netAvailableAfter(ExposureBucket memory bucket, uint256 expectedRelease, uint256 expectedConsume)
        internal
        pure
        returns (uint256)
    {
        uint256 used = expectedRelease >= bucket.used ? 0 : bucket.used - expectedRelease;
        uint256 consumed = used + bucket.pending + bucket.reserved + expectedConsume;
        return consumed >= bucket.limit ? 0 : bucket.limit - consumed;
    }
}
