// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IRouter.sol";
import "../VaultBase.sol";
import "./IMasterChefIron.sol";

contract VaultIronLP is VaultBase {
    using SafeERC20 for IERC20;

    IMasterChefIron public masterChef;
    address public token0;
    address public token1;
    address public rewardToken;
    uint256 public poolId;
    address public liquidityRouter;

    mapping(address => mapping(address => RouteInfo)) public routes;

    uint256 public swapTimeout;

    // hardcoded when deploy
    constructor(
        address _liquidityRouter,
        IMasterChefIron _masterChef,
        uint256 _poolId
    ) VaultBase() {
        liquidityRouter = _liquidityRouter;
        poolId = _poolId;
        masterChef = _masterChef;
        (wantAddress, , , ) = _masterChef.poolInfo(poolId);
        rewardToken = _masterChef.rewardToken();
        token0 = IUniswapV2Pair(wantAddress).token0();
        token1 = IUniswapV2Pair(wantAddress).token1();
        _syncSwapRoutes();
    }

    // ========== views =================

    function balanceInFarm() public view override returns (uint256) {
        (uint256 _amount, ) = masterChef.userInfo(poolId, address(this));
        return _amount;
    }

    function pending() public view override returns (uint256) {
        return masterChef.pendingReward(poolId, address(this));
    }

    function canAbandon() public view override returns (bool) {
        bool _noRewardTokenLeft = IERC20(rewardToken).balanceOf(address(this)) == 0;
        bool _noLpTokenLeft = IERC20(wantAddress).balanceOf(address(this)) == 0;
        bool _noPending = pending() == 0;
        return _noRewardTokenLeft && _noLpTokenLeft && _noPending;
    }

    function info()
        external
        view
        virtual
        override
        returns (
            uint256 _templateId,
            uint256 _balanceInFarm,
            uint256 _pendingRewards,
            bool _abandoned,
            bool _canDeposit,
            bool _canAbandon
        )
    {
        IVaultPolicy policy = getPolicy();
        _templateId = templateId;
        _balanceInFarm = balanceInFarm();
        _pendingRewards = pending();
        _canDeposit = policy.canDeposit(address(this), owner);
        _canAbandon = canAbandon();
        _abandoned = abandoned;
    }

    // ========== vault core functions ===========

    function compound() external override onlyHarvestor {
        // Harvest farm tokens
        uint256 _initBalance = balanceInFarm();
        _widthdrawFromFarm(0);

        if (_isWETH(rewardToken)) {
            _wrapETH();
        }

        // Converts farm tokens into want tokens
        uint256 earnedAmt = IERC20(rewardToken).balanceOf(address(this));

        if (rewardToken != token0) {
            _swap(rewardToken, token0, earnedAmt / 2);
        }

        if (rewardToken != token1) {
            _swap(rewardToken, token1, earnedAmt / 2);
        }

        IERC20 _token0 = IERC20(token0);
        IERC20 _token1 = IERC20(token1);
        // Get want tokens, ie. add liquidity
        uint256 token0Amt = _token0.balanceOf(address(this));
        uint256 token1Amt = _token1.balanceOf(address(this));
        if (token0Amt > 0 && token1Amt > 0) {
            _token0.safeIncreaseAllowance(liquidityRouter, token0Amt);
            _token1.safeIncreaseAllowance(liquidityRouter, token1Amt);
            IUniswapV2Router(liquidityRouter).addLiquidity(
                token0,
                token1,
                token0Amt,
                token1Amt,
                0,
                0,
                address(this),
                block.timestamp + swapTimeout
            );
        }

        lastEarnBlock = block.number;

        _depositToFarm();
        _cleanUp();

        uint256 _afterBalance = balanceInFarm();
        if (_afterBalance > _initBalance) {
            emit Earned(wantAddress, _afterBalance - _initBalance);
        } else {
            emit Earned(wantAddress, 0);
        }
    }

    function deposit(uint256 _wantAmt) public override onlyOwner nonReentrant returns (uint256) {
        IERC20(wantAddress).safeTransferFrom(address(msg.sender), address(this), _wantAmt);
        _depositToFarm();
        return _wantAmt;
    }

    function withdrawAll() external override onlyOwner returns (uint256 _withdrawBalance) {
        uint256 _balance = balanceInFarm();
        _withdrawBalance = withdraw(_balance);
        _cleanUp();
        _withdrawFromVault();
        emit Exit(_withdrawBalance);
    }

    function withdraw(uint256 _wantAmt) public override onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt <= 0");
        _widthdrawFromFarm(_wantAmt);
        uint256 _balance = IERC20(rewardToken).balanceOf(address(this));
        _withdrawFromVault();
        return _balance;
    }

    function claimRewards() external override onlyOwner {
        _widthdrawFromFarm(0);
        uint256 _balance = IERC20(rewardToken).balanceOf(address(this));
        if (_balance > 0) {
            IERC20(rewardToken).safeTransfer(msg.sender, _balance);
        }
    }

    function abandon() external override onlyOwner {
        require(canAbandon(), "Vault cannot be abandoned");
        abandoned = true;
    }

    function syncSwapRoutes() external onlyOwner {
        _syncSwapRoutes();
    }

    // ============= internal functions ================

    function _syncSwapRoutes() internal override {
        _addRouteInfo(rewardToken, token0);
        _addRouteInfo(rewardToken, token1);
        _addRouteInfo(token0, rewardToken);
        _addRouteInfo(token1, rewardToken);
    }

    function _addRouteInfo(address _from, address _to) internal {
        if (_from != _to) {
            IRouter router = getRouter();
            (address _router, address[] memory _path) = router.getSwapRoute(_from, _to);
            require(_from != address(0), "Src token is invalid");
            require(_to != address(0), "Dst token is invalid");
            require(_router != address(0), "Router is invalid");
            require(_path[0] == _from, "Route must start with src token");
            require(_path[_path.length - 1] == _to, "Route must end with dst token");
            routes[_from][_to] = RouteInfo(_router, _path);
        }
    }

    function _getSwapRoute(address _fromToken, address _toToken) internal view returns (address _router, address[] memory _path) {
        RouteInfo storage _info = routes[_fromToken][_toToken];
        _router = _info.router;
        _path = _info.path;
    }

    function _withdrawFromVault() internal {
        uint256 _dustRewardBal = IERC20(rewardToken).balanceOf(address(this));
        if (_dustRewardBal > 0) {
            IERC20(rewardToken).safeTransfer(msg.sender, _dustRewardBal);
        }
        uint256 _wantBalance = IERC20(wantAddress).balanceOf(address(this));
        if (_wantBalance > 0) {
            IERC20(wantAddress).safeTransfer(msg.sender, _wantBalance);
        }
    }

    function _cleanUp() internal {
        // Converts dust tokens into earned tokens, which will be reinvested on the next earn().
        // Converts token0 dust (if any) to earned tokens
        uint256 token0Amt = IERC20(token0).balanceOf(address(this));
        if (token0 != rewardToken && token0Amt > 0) {
            _swap(token0, rewardToken, token0Amt);
        }

        // Converts token1 dust (if any) to earned tokens
        uint256 token1Amt = IERC20(token1).balanceOf(address(this));
        if (token1 != rewardToken && token1Amt > 0) {
            _swap(token1, rewardToken, token1Amt);
        }
    }

    function _depositToFarm() internal canDeposit {
        IERC20 wantToken = IERC20(wantAddress);
        uint256 wantAmt = wantToken.balanceOf(address(this));
        wantToken.safeIncreaseAllowance(address(masterChef), wantAmt);
        masterChef.deposit(poolId, wantAmt);
        emit Deposited(wantAmt);
    }

    function _widthdrawFromFarm(uint256 _wantAmt) internal {
        masterChef.withdraw(poolId, _wantAmt);
        emit Withdraw(_wantAmt);
    }

    function _swap(
        address _inputToken,
        address _outputToken,
        uint256 _inputAmount
    ) internal {
        if (_inputAmount == 0) {
            return;
        }
        (address _router, address[] memory _path) = _getSwapRoute(_inputToken, _outputToken);
        require(_router != address(0), "invalid route");
        require(_path[0] == _inputToken, "Route must start with src token");
        require(_path[_path.length - 1] == _outputToken, "Route must end with dst token");
        IERC20(_inputToken).safeApprove(_router, 0);
        IERC20(_inputToken).safeApprove(_router, _inputAmount);
        _safeSwap(_router, _inputAmount, slippage, _path, address(this), block.timestamp + swapTimeout);
    }
}
