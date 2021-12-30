// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ITreasury {
    function mintRewards( address _recipient, uint _amount ) external;
}

contract Distributor is Ownable {
    uint256 public rewardsRate;
    uint256 public lastRebaseTimestamp;
    ITreasury public treasury;
    address public recipient;

    constructor(address _treasury, address _recipient, uint256 _rewardRate){
        treasury = ITreasury(_treasury);
        recipient = _recipient;
        rewardsRate = _rewardRate;
        lastRebaseTimestamp = block.timestamp;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        rewardsRate = _rewardRate;
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = ITreasury(_treasury);
    }

    function setRecipeint(address _recipient) public onlyOwner {
        recipient = _recipient;
    }

    function setRebaseTimestamp(uint256 time) public onlyOwner {
        lastRebaseTimestamp = time;
    }

    function distribute() public {
        if(lastRebaseTimestamp + 28800 < block.timestamp){
            lastRebaseTimestamp = lastRebaseTimestamp + 28800;
            treasury.mintRewards( recipient, rewardsRate );
        }
    }
}
