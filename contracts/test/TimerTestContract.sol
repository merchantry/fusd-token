// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TimerTestContract {
    uint256 private deployedAt;

    uint256 private waitingTime;

    bool private actionCompleted;

    constructor(uint256 currentTime, uint256 _waitingTime) {
        deployedAt = currentTime;
        waitingTime = _waitingTime;
        actionCompleted = false;
    }

    function isReady(uint256 currentTime) public view returns (bool) {
        return currentTime >= deployedAt + waitingTime;
    }

    function setActionCompleted() public {
        actionCompleted = true;
    }

    function getActionCompleted() public view returns (bool) {
        return actionCompleted;
    }
}
