// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IQuickswapStakingRewards {
    function stakingToken() external view returns (address);

    function rewardsToken() external view returns (address);

    function balanceOf(address _account) external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function exit() external;

    function getReward() external;
}
