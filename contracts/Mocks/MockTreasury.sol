// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IERC20{
    function mint(address usr, uint wad) external;
}

contract Treasury {
    IERC20 token;
    constructor(address _token){
       token = IERC20(_token); 
    }

    function mintRewards( address _recipient, uint _amount ) external {
        token.mint(_recipient, _amount);
    }
}
