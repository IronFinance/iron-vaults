// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRouter.sol";

contract Router is IRouter, Ownable {
    mapping(address => mapping(address => RouteInfo)) public routes;

    function addRoute(
        address _from,
        address _to,
        address _router,
        address[] calldata path
    ) external onlyOwner {
        require(_from != address(0), "Src token is invalid");
        require(_to != address(0), "Dst token is invalid");
        require(_from != _to, "Src token must be diff from Dst token");
        require(_router != address(0), "Router is invalid");
        require(path[0] == _from, "Route must start with src token");
        require(path[path.length - 1] == _to, "Route must end with dst token");
        RouteInfo memory _info = RouteInfo(_router, path);
        routes[_from][_to] = _info;
    }

    function removeRoute(address _from, address _to) external onlyOwner {
        address[] memory _empty;
        routes[_from][_to] = RouteInfo(address(0), _empty);
    }

    function getSwapRoute(address _fromToken, address _toToken)
        external
        view
        override
        returns (address _router, address[] memory _path)
    {
        RouteInfo storage _info = routes[_fromToken][_toToken];
        _router = _info.router;
        _path = _info.path;
    }
}
