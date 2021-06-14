// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IMasterChefIron {
    function poolInfo(uint256 poolId)
        external
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accRewardPerShare
        );

    function userInfo(uint256 poolId, address user) external view returns (uint256 amount, uint256 debt);

    function pendingReward(uint256 _pid, address _user) external view returns (uint256);

    function deposit(uint256 poolId, uint256 amount) external;

    function withdraw(uint256 poolId, uint256 amount) external;

    function rewardToken() external view returns (address);

    function add(
        uint256 _allocPoint,
        address _lpToken,
        bool _withUpdate
    ) external;
}
