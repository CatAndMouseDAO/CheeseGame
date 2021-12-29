// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CheeseGame is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public index;
    IERC20 public rewardsToken;
    IERC1155 public stakedToken;

    uint public MOUSE;
    uint public CAT;
    uint public TRAP;

    mapping (address => UserInfo) userInfo;
    address[] public traps;

    struct UserInfo {
        uint mouseBalance;
        uint catBalance;
        uint trapBalance;
        uint mouseIndex;
        uint catIndex;
        uint mouseTimestamp;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _stakedToken) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        stakedToken = IERC1155(_stakedToken);
        index = 1100000000;
        MOUSE = 0;
        CAT = 1;
        TRAP = 2;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function stake(uint _id, uint _amount) public {
        stakedToken.safeTransferFrom(msg.sender, address(this), _id, _amount, "");

        uint _mouseTimestamp = userInfo[msg.sender].mouseTimestamp;
        uint _mouseBalance = userInfo[msg.sender].mouseBalance;
        uint _catBalance = userInfo[msg.sender].catBalance;
        uint _trapBalance = userInfo[msg.sender].trapBalance;
        uint _mouseIndex = userInfo[msg.sender].mouseIndex;
        uint _catIndex = userInfo[msg.sender].catIndex;

        if(_id == MOUSE) {
            _mouseBalance = _mouseBalance + _amount;
            _mouseIndex = index;
            _mouseTimestamp = block.timestamp;
        } else if(_id == CAT) {
            _catBalance = _catBalance + _amount;
            _catIndex = index;
        } else if(_id == TRAP) {
            _trapBalance = _trapBalance + _amount;
            for (uint i = 0; i < _amount; i++) {
                addTrap(msg.sender);
            }
        }

        userInfo[msg.sender] = UserInfo(_mouseBalance, _catBalance, _trapBalance, _mouseIndex, _catIndex, _mouseTimestamp);
    }

    function unstake(uint _id, uint _amount) external {
        if(_id == MOUSE){
            require(_amount <= userInfo[msg.sender].mouseBalance, "Unstake: amount too high" );
            require((block.timestamp - userInfo[msg.sender].mouseTimestamp) >= 172800, "Must wait 2 days to unstake mice");
        } else if(_id == CAT){
            require(_amount <= userInfo[msg.sender].catBalance);
        } else if(_id == TRAP){
            require(_amount <= userInfo[msg.sender].trapBalance);
        }


        uint _mouseTimestamp = userInfo[msg.sender].mouseTimestamp;
        uint _mouseBalance = userInfo[msg.sender].mouseBalance;
        uint _catBalance = userInfo[msg.sender].catBalance;
        uint _trapBalance = userInfo[msg.sender].trapBalance;
        uint _mouseIndex = userInfo[msg.sender].mouseIndex;
        uint _catIndex = userInfo[msg.sender].catIndex;

        if(_id == MOUSE) {
            _mouseBalance = _mouseBalance - _amount;
            _mouseIndex = index;
            _mouseTimestamp = block.timestamp;
        } else if(_id == CAT) {
            _catBalance = _catBalance - _amount;
            _catIndex = index;
        } else if(_id == TRAP) {
            _trapBalance = _trapBalance - _amount;
            for (uint i = 0; i < _amount; i++) {
                removeTrap(msg.sender);
            }
        }
        
        userInfo[msg.sender] = UserInfo(_mouseBalance, _catBalance, _trapBalance, _mouseIndex, _catIndex, _mouseTimestamp);

        if(_id == MOUSE){
            uint miceStolen;
            uint miceAttacked;
            uint rpm = rewardsPerMouse();
            
            for(uint i = 0; i < _amount; i++){
                uint rand = getRand();
                if (rand < 5) {
                    miceStolen++;
                } else if(rand < 45){
                    miceAttacked++;
                }
            }
            uint totalRewards = rpm * _amount;
            uint catRewards = (miceAttacked * rpm);
            uint miceRewards = totalRewards - catRewards - (miceStolen * rpm);
            uint amount = _amount - miceStolen;
            uint id = _id;
            
            stakedToken.safeTransferFrom(address(this), msg.sender, id, amount, "");
            for(uint i = 0; i < miceStolen; i++){
                if(stakedToken.balanceOf(address(this), TRAP) > 0){
                uint winnerIdx = getTrapWinnerId();
                address winner = traps[winnerIdx];
                removeTrapByIdx(winnerIdx);
                stakedToken.safeTransferFrom(address(this), winner, MOUSE, 1, "");
                stakedToken.safeTransferFrom(address(this), winner, TRAP, 1, "");
                //rewardsToken.transferFrom(address(this), winner, rpm);
                } else {
                    miceStolen--;
                }
            }
            //rewardsToken.transferFrom(address(this), msg.sender, miceRewards);
        } else {
            stakedToken.safeTransferFrom(address(this), msg.sender, _id, _amount, "");
        }
    }

    function rewardsPerMouse() public pure returns (uint) {
        return 1;
    }

    function getRand() public view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, gasleft()))) % 100;
        //return (uint(vrf()) % 100);
    }

    function getTrapWinnerId() public view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % traps.length;
        //return (uint(vrf()) % traps.length);
    }

    function vrf() public view returns (bytes32 result) {
        uint[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
            invalid()
        }
        result := mload(memPtr)
        }
    }

   function isTrap(address _address) public view returns(bool, uint256) {
       for (uint256 s = 0; s < traps.length; s += 1){
           if (_address == traps[s]) return (true, s);
       }
       return (false, 0);
   }

   function addTrap(address _address) public {
       traps.push(_address);
   }

   function removeTrap(address _address) public {
       (bool _isStakeholder, uint256 s) = isTrap(_address);
       if(_isStakeholder){
           traps[s] = traps[traps.length - 1];
           traps.pop();
       }
    }

   function removeTrapByIdx(uint idx) public {
        traps[idx] = traps[traps.length - 1];
        traps.pop();
    }

    function onERC1155Received(address operator, address, uint256, uint256, bytes memory) external virtual returns (bytes4) {
        require(operator == address(this), "Operator not staking contract");
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

}