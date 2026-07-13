// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AddressSet {
    struct Set {
        address[] values;
        mapping(address => uint256) indexPlusOne;
    }

    function add(Set storage set, address value) internal returns (bool) {
        require(value != address(0), "ADDRESS_ZERO");
        if (contains(set, value)) return false;
        set.values.push(value);
        set.indexPlusOne[value] = set.values.length;
        return true;
    }

    function remove(Set storage set, address value) internal returns (bool) {
        uint256 index = set.indexPlusOne[value];
        if (index == 0) return false;
        uint256 lastIndex = set.values.length;
        if (index != lastIndex) {
            address last = set.values[lastIndex - 1];
            set.values[index - 1] = last;
            set.indexPlusOne[last] = index;
        }
        set.values.pop();
        delete set.indexPlusOne[value];
        return true;
    }

    function contains(Set storage set, address value) internal view returns (bool) {
        return set.indexPlusOne[value] != 0;
    }

    function length(Set storage set) internal view returns (uint256) {
        return set.values.length;
    }

    function at(Set storage set, uint256 index) internal view returns (address) {
        require(index < set.values.length, "INDEX");
        return set.values[index];
    }

    function asArray(Set storage set) internal view returns (address[] memory out) {
        out = new address[](set.values.length);
        for (uint256 i = 0; i < set.values.length; i++) {
            out[i] = set.values[i];
        }
    }

    function slice(Set storage set, uint256 start, uint256 count) internal view returns (address[] memory out) {
        if (start >= set.values.length) return new address[](0);
        uint256 end = start + count;
        if (end > set.values.length) end = set.values.length;
        out = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = set.values[i];
        }
    }
}
