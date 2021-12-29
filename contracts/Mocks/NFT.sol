// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

pragma solidity ^0.8.0;

/// @title Test token
/// @author Nazh_G
/// @notice this token implements ERC1155 for testing
contract NFT is ERC1155 {
    uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant THORS_HAMMER = 2;
    uint256 public constant SWORD = 3;
    uint256 public constant SHIELD = 4;

    constructor()
        ERC1155(
            "https://raw.githubusercontent.com/abcoathup/SampleERC1155/master/api/token/{id}.json"
        )
    {
        mintNFTs(10000);
    }

    function mintNFTs(uint256 amount) public {
        _mint(msg.sender, GOLD, amount, "");
        _mint(msg.sender, SILVER, amount, "");
        _mint(msg.sender, THORS_HAMMER, amount, "");
    }
}
