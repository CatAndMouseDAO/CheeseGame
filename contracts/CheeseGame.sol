// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract IRebaser {
    function rebase( uint256 profit_, uint256 epoch_) public returns ( uint256 ) {}
    function index() public view returns ( uint256 ) {}
}

contract CheeseGame is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IERC20 public rewardsToken;
    IERC1155 public stakedToken;

    IRebaser[] public rebasers;

    uint256 public rewardRate;
    uint256 public nextCatPool;

    uint256 public MOUSE;
    uint256 public CAT;
    uint256 public TRAP;

    uint256 public lastRebaseTimestamp;
    uint256 public epoch;

    mapping (address => UserInfo) userInfo;
    address[] public traps;

    struct UserInfo {
        mapping (uint256 => uint256) balances;
        mapping (uint256 => uint256) indexes;
        mapping (uint256 => uint256) timestamps;
    }

    uint256 private _NOT_ENTERED;
    uint256 private _ENTERED;

    uint256 private _status;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        address _stakedToken,
        address _rewardsToken,
        address _miceRebaser,
        address _catRebaser
    ) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        MOUSE = 0;
        CAT = 1;
        TRAP = 2;

        _NOT_ENTERED = 1;
        _ENTERED = 2;
        _status = _NOT_ENTERED;

        rewardRate = 600000000000;

        stakedToken = IERC1155(_stakedToken);
        rewardsToken = IERC20(_rewardsToken);

        rebasers.push(IRebaser(_miceRebaser));
        rebasers.push(IRebaser(_catRebaser));

        lastRebaseTimestamp = block.timestamp;
    }

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        rewardRate = _rewardRate;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function rebase() public {
        if(lastRebaseTimestamp + 28800 < block.timestamp){
            lastRebaseTimestamp = lastRebaseTimestamp + 28800;
            rebasers[MOUSE].rebase(rewardRate, epoch);
            rebasers[CAT].rebase(nextCatPool, epoch);
            nextCatPool = 0;
            epoch++;
        }
    }

    function adjustBalances(bool add, uint256 _id, uint256 _amount) internal {
        if(add){
            if(_id == MOUSE) {
                userInfo[msg.sender].balances[MOUSE] = userInfo[msg.sender].balances[MOUSE] + _amount;
                userInfo[msg.sender].indexes[MOUSE] = rebasers[MOUSE].index();
                userInfo[msg.sender].timestamps[MOUSE] = block.timestamp;
            } else if(_id == CAT) {
                userInfo[msg.sender].balances[CAT] = userInfo[msg.sender].balances[CAT] + _amount;
                userInfo[msg.sender].indexes[CAT] = rebasers[CAT].index();
            } else if(_id == TRAP) {
                userInfo[msg.sender].balances[TRAP] = userInfo[msg.sender].balances[TRAP] + _amount;
                for (uint256 i = 0; i < _amount; i++) {
                    addTrap(msg.sender);
                }
            }
        } else {
            if(_id == MOUSE) {
                userInfo[msg.sender].balances[MOUSE] = userInfo[msg.sender].balances[MOUSE] - _amount;
                userInfo[msg.sender].indexes[MOUSE] = rebasers[MOUSE].index();
                userInfo[msg.sender].timestamps[MOUSE] = block.timestamp;
            } else if(_id == CAT) {
                userInfo[msg.sender].balances[CAT] = userInfo[msg.sender].balances[CAT] - _amount;
                userInfo[msg.sender].indexes[CAT] = rebasers[CAT].index();
            } else if(_id == TRAP) {
                userInfo[msg.sender].balances[TRAP] = userInfo[msg.sender].balances[TRAP] - _amount;
                for (uint256 i = 0; i < _amount; i++) {
                    removeTrap(msg.sender);
                }
            }
        }
    }

    function stake(uint256 _id, uint256 _amount) public nonReentrant {
        require(_amount > 0, "Stake: can't stake 0 tokens");
        rebase();
        stakedToken.safeTransferFrom(msg.sender, address(this), _id, _amount, "");
        adjustBalances(true, _id, _amount);
    }

    function unstake(uint256 _id, uint256 _amount) public nonReentrant {
        require(_amount <= userInfo[msg.sender].balances[_id], "Unstake: amount too high" );
        require((_id != MOUSE) || ((block.timestamp - userInfo[msg.sender].timestamps[MOUSE]) >= 172800), "Unstake: mice are locked");
        require(_id < 3, "Unstake: id not supported");
        rebase();

        if(_id == MOUSE){
            uint256 miceStolen;
            uint256 miceAttacked;
            
            for(uint256 i = 0; i < _amount; i++){
                uint256 rand = getRand();
                if (rand < 5) {
                    miceStolen++;
                } else if(rand < 45){
                    miceAttacked++;
                }
            }

            uint256 mouseBalance = userInfo[msg.sender].balances[MOUSE];
            uint256 totalRewards = getRewards(msg.sender, MOUSE);
            adjustBalances(false, _id, _amount);
            uint256 rpm = totalRewards / mouseBalance;
            
            for(uint256 i = 0; i < miceStolen; i++){
                if(stakedToken.balanceOf(address(this), TRAP) > 0){
                    uint256 winnerIdx = getTrapWinnerId();
                    address winner = traps[winnerIdx];
                    removeTrapByIdx(winnerIdx);
                    stakedToken.safeTransferFrom(address(this), winner, MOUSE, 1, "");
                    stakedToken.safeTransferFrom(address(this), winner, TRAP, 1, "");
                    rewardsToken.transferFrom(address(this), winner, rpm);
                } else {
                    miceStolen--;
                    miceAttacked++;
                }
            }
            
            uint256 catRewards = (miceAttacked * rpm);
            nextCatPool += catRewards;
            uint256 miceRewards = totalRewards - catRewards - (miceStolen * rpm);
            uint256 amount = _amount - miceStolen;

            stakedToken.safeTransferFrom(address(this), msg.sender, _id, amount, "");
            rewardsToken.transferFrom(address(this), msg.sender, miceRewards);
        } else if(_id == CAT) {
            uint256 totalRewards = getRewards(msg.sender, _id);
            adjustBalances(false, _id, _amount);
            rewardsToken.transferFrom(address(this), msg.sender, totalRewards);
            stakedToken.safeTransferFrom(address(this), msg.sender, _id, _amount, "");
        } else {
            adjustBalances(false, _id, _amount);
            stakedToken.safeTransferFrom(address(this), msg.sender, _id, _amount, "");
        }
    }

    function claimRewards(uint256 id) public nonReentrant {
        require(id < 2);
        uint256 rewards = getRewards(msg.sender, id);
        if(id == MOUSE){
            rewards = rewards * 3 / 4;
            userInfo[msg.sender].timestamps[id] = block.timestamp;
        }
        userInfo[msg.sender].indexes[id] = rebasers[id].index();
    }

    function getRewards(address user, uint256 id) public view returns (uint256) {
        require(id < 2);
        uint256 lastIdx = userInfo[msg.sender].indexes[id];
        if(lastIdx == 0){
            return 0;
        }
        uint256 balance = userInfo[user].balances[id];
        uint256 currentIdx = rebasers[id].index();
        return balance * (currentIdx - lastIdx); 
    }

    function getRand() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, gasleft()))) % 100;
        //return (uint(vrf()) % 100);
    }

    function getTrapWinnerId() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % traps.length;
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

   function removeTrapByIdx(uint256 idx) public {
        traps[idx] = traps[traps.length - 1];
        traps.pop();
    }

    function onERC1155Received(address operator, address, uint256, uint256, bytes memory) external virtual returns (bytes4) {
        require(operator == address(this), "Operator not staking contract");
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

}