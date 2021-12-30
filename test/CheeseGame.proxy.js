// test/CheeseGame.js
// Load dependencies
const { expect } = require('chai');
const { ethers } = require("hardhat");

const initialIndex = '1000000000'
let cg, nft, cheez, miceRebaser, catRebaser;
let owner, user1;
// Start test block
describe('CheeseGame', function () {
  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    NFT = await ethers.getContractFactory("NFT");
    nft = await NFT.deploy();

    CHEEZ = await ethers.getContractFactory("CHEEZ");
    cheez = await CHEEZ.deploy(0);

    Rebaser = await ethers.getContractFactory("contracts/Rebase.sol:Rebaser");
    miceRebaser = await Rebaser.deploy();
    catRebaser = await Rebaser.deploy()
    await miceRebaser.setIndex(initialIndex);
    await catRebaser.setIndex(initialIndex);

    CG = await ethers.getContractFactory("CheeseGame");
    cg = await upgrades.deployProxy(CG, [nft.address, cheez.address, miceRebaser.address, catRebaser.address], { kind: 'uups' });

    await miceRebaser.initialize( cg.address, nft.address, 0) 
    await catRebaser.initialize( cg.address, nft.address, 1) 

  });
 
  // Test case
  it('retrieve index', async function () { 
    expect((await miceRebaser.index()).toString()).to.equal(initialIndex);
  });

  it('retrieve random number', async function () { 
    expect(parseInt((await cg.getRand()).toString())).to.be.greaterThanOrEqual(0);
  });

  it('Stake mice', async function () { 
    let balanceBefore = await nft.balanceOf(owner.address, 0)
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(0, 50);
    let balanceAfter = await nft.balanceOf(owner.address, 0)
    expect(parseInt(balanceBefore)).to.be.equal(parseInt(balanceAfter)+50);
  });

  /*
  it('Unstake mice', async function () { 
    await network.provider.send("evm_setNextBlockTimestamp", [Math.floor(Date.now() / 1000) + 100])
    await network.provider.send("evm_mine")
  
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(0, 7500);
    await cg.stake(2, 500);

    await network.provider.send("evm_setNextBlockTimestamp", [Math.floor(Date.now() / 1000) + 100 + 172801])
    await network.provider.send("evm_mine")

    let balanceBefore = await nft.balanceOf(owner.address, 0)
    await cg.unstake(0, 7500);
    let balanceAfter = await nft.balanceOf(owner.address, 0)
    expect(parseInt(balanceBefore)).to.be.lessThan(parseInt(balanceAfter));
  });
  */
  it('Should set circ supply to mice staked * index', async function () { 
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(0, 50);
    let index = await miceRebaser.index()
    let circ = await miceRebaser.circulatingSupply()
    expect(index.mul(ethers.BigNumber.from("50"))).to.be.equal(circ);
  });

  it('Should rebase', async function () { 
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(0, 600);

    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")

    await cg.rebase()
    let index = await miceRebaser.index()
    //console.log(index)
    let circ = await miceRebaser.circulatingSupply()
    expect(circ).to.be.equal(index.mul(ethers.BigNumber.from("600")));
  });
  
  it('Should calculate rebase rewards', async function () { 
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(1, 10);
    await cg.stake(0, 600);
    let epoch = await cg.epoch()
    //console.log(epoch)
    await nft.connect(user1).mintNFTs(600)
    await nft.connect(user1).setApprovalForAll(cg.address, true);
    await cg.connect(user1).stake(0, 600);
    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")
    await cg.rebase()
    let index = await miceRebaser.index()
    //console.log(index)
    epoch = await cg.epoch()
    //console.log(epoch)
    let rewards = await cg.getRewards(owner.address, 0)
    //console.log(rewards)
    rewards = await cg.getRewards(owner.address, 0)
    //console.log(rewards)
    expect(parseInt(rewards.toString())).to.be.equal(300000000000);
  });
});
