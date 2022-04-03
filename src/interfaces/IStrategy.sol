// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.12;

interface IStrategy {
    function estimatedTotalAssets() external view returns (uint256);
}
