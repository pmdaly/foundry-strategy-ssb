// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.12;

interface IStrategy {
    function estimatedTotalAssets() external view returns (uint256);

    function vault() external view returns (address);

    function setEmergencyExit() external;

    function harvest() external;
}
