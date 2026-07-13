// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DelegationKeys {
    bytes32 internal constant DIRECT_DOMAIN = keccak256("VALIANT_DIRECT_CREDIT_LINE");
    bytes32 internal constant MANAGED_DOMAIN = keccak256("VALIANT_MANAGED_CREDIT_LINE");
    bytes32 internal constant DIRECT_ROUTE_DOMAIN = keccak256("VALIANT_DIRECT_LOAN_ROUTE");
    bytes32 internal constant MANAGED_ROUTE_DOMAIN = keccak256("VALIANT_MANAGED_LOAN_ROUTE");

    function directLine(address sponsor, address delegate) internal pure returns (bytes32) {
        return keccak256(abi.encode(DIRECT_DOMAIN, sponsor, delegate));
    }

    function managedLine(address sponsor, address manager, address borrower) internal pure returns (bytes32) {
        return keccak256(abi.encode(MANAGED_DOMAIN, sponsor, manager, borrower));
    }

    function directRoute(address sponsor, address borrower) internal pure returns (bytes32) {
        return keccak256(abi.encode(DIRECT_ROUTE_DOMAIN, sponsor, borrower));
    }

    function managedRoute(address sponsor, address manager, address borrower) internal pure returns (bytes32) {
        return keccak256(abi.encode(MANAGED_ROUTE_DOMAIN, sponsor, manager, borrower));
    }

    function routeFromFlag(address sponsor, address manager, address borrower, bool managed)
        internal
        pure
        returns (bytes32)
    {
        return managed ? managedRoute(sponsor, manager, borrower) : directRoute(sponsor, borrower);
    }
}
