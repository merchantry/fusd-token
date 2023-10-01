// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../libraries/ERC20Utils.sol";

abstract contract TokenAdapter {
    ERC20 private token;

    constructor(address _token) {
        token = ERC20(_token);
    }

    function _updateToken(address _token) internal {
        require(
            ERC20Utils.getTokenKey(_token) == ERC20Utils.getTokenKey(address(token)),
            "Token adapter: invalid token symbol"
        );

        token = ERC20(_token);
    }

    function _getToken() internal view returns (address) {
        return address(token);
    }
}
