// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IRouter {
    struct RouteInfo {
        address router;
        address[] path;
    }

    function getSwapRoute(address _fromToken, address _toToken)
        external
        view
        returns (address _router, address[] memory _path);
}
