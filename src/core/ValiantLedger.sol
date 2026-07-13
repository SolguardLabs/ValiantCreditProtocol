// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AddressSet} from "../libraries/AddressSet.sol";

contract ValiantLedger {
    using AddressSet for AddressSet.Set;

    event AccountRegistered(address indexed account);
    event AccountTagged(address indexed account, bytes32 indexed tag, bool enabled);
    event RouteIndexed(address indexed account, bytes32 indexed route, bool enabled);

    address public immutable market;

    mapping(address => AddressSet.Set) internal _accountPeers;
    mapping(address => bytes32[]) internal _accountRoutes;
    mapping(address => mapping(bytes32 => bool)) internal _routeKnown;
    mapping(address => mapping(bytes32 => bool)) public accountTag;
    mapping(address => bool) public registered;

    modifier onlyMarket() {
        require(msg.sender == market, "ONLY_MARKET");
        _;
    }

    constructor(address market_) {
        require(market_ != address(0), "MARKET_ZERO");
        market = market_;
    }

    function register(address account) external onlyMarket {
        if (!registered[account]) {
            registered[account] = true;
            emit AccountRegistered(account);
        }
    }

    function setTag(address account, bytes32 tag, bool enabled) external onlyMarket {
        accountTag[account][tag] = enabled;
        emit AccountTagged(account, tag, enabled);
    }

    function addPeer(address account, address peer) external onlyMarket returns (bool) {
        bool added = _accountPeers[account].add(peer);
        if (added && !registered[account]) {
            registered[account] = true;
            emit AccountRegistered(account);
        }
        return added;
    }

    function removePeer(address account, address peer) external onlyMarket returns (bool) {
        return _accountPeers[account].remove(peer);
    }

    function indexRoute(address account, bytes32 route) external onlyMarket returns (bool) {
        if (_routeKnown[account][route]) return false;
        _routeKnown[account][route] = true;
        _accountRoutes[account].push(route);
        emit RouteIndexed(account, route, true);
        return true;
    }

    function clearRoute(address account, bytes32 route) external onlyMarket returns (bool) {
        if (!_routeKnown[account][route]) return false;
        _routeKnown[account][route] = false;
        emit RouteIndexed(account, route, false);
        return true;
    }

    function peerCount(address account) external view returns (uint256) {
        return _accountPeers[account].length();
    }

    function peerAt(address account, uint256 index) external view returns (address) {
        return _accountPeers[account].at(index);
    }

    function peers(address account) external view returns (address[] memory) {
        return _accountPeers[account].asArray();
    }

    function peerSlice(address account, uint256 start, uint256 count) external view returns (address[] memory) {
        return _accountPeers[account].slice(start, count);
    }

    function routes(address account) external view returns (bytes32[] memory out) {
        bytes32[] storage stored = _accountRoutes[account];
        out = new bytes32[](stored.length);
        for (uint256 i = 0; i < stored.length; i++) {
            out[i] = stored[i];
        }
    }

    function routeSlice(address account, uint256 start, uint256 count) external view returns (bytes32[] memory out) {
        bytes32[] storage stored = _accountRoutes[account];
        if (start >= stored.length) return new bytes32[](0);
        uint256 end = start + count;
        if (end > stored.length) end = stored.length;
        out = new bytes32[](end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = stored[i];
        }
    }
}
