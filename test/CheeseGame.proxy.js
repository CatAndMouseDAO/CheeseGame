// test/CheeseGame.js
// Load dependencies
const { expect } = require('chai');
const { ethers } = require("hardhat");

const initialIndex = '1000000000'
let cg, nft, cheez, miceRebaser, catRebaser, treasury;
let owner, user1;
// Start test block
describe('CheeseGame', function () {
  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    NFT = await ethers.getContractFactory("NFT");
    nft = await NFT.deploy();

    CHEEZ = await ethers.getContractFactory("CHEEZ");
    cheez = await CHEEZ.deploy(0);

    Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(cheez.address);

    Rebaser = await ethers.getContractFactory("contracts/Rebase.sol:Rebaser");
    miceRebaser = await Rebaser.deploy();
    catRebaser = await Rebaser.deploy()
    await miceRebaser.setIndex(initialIndex);
    await catRebaser.setIndex(initialIndex);

    CG = await ethers.getContractFactory("CheeseGame");
    cg = await upgrades.deployProxy(CG, [nft.address, cheez.address, miceRebaser.address, catRebaser.address], { kind: 'uups' });

    await miceRebaser.initialize( cg.address, nft.address, 0) 
    await catRebaser.initialize( cg.address, nft.address, 1) 

    Dist = await ethers.getContractFactory("Distributor");
    dist = await Dist.deploy(treasury.address, cg.address, 600e9);

    await cg.setDistributor(dist.address);

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

  it('Stake cats', async function () { 
    let balanceBefore = await nft.balanceOf(owner.address, 1)
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(1, 50);
    let balanceAfter = await nft.balanceOf(owner.address, 1)
    expect(parseInt(balanceBefore)).to.be.equal(parseInt(balanceAfter)+50);
  });  

  it('Stake traps', async function () { 
    let balanceBefore = await nft.balanceOf(owner.address, 2)
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(2, 50);
    let balanceAfter = await nft.balanceOf(owner.address, 2)
    expect(parseInt(balanceBefore)).to.be.equal(parseInt(balanceAfter)+50);
  });  


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
    await cg.stake(0, 300);
    let epoch = await cg.epoch()
    //console.log(epoch)
    await nft.connect(user1).mintNFTs(600)
    await nft.connect(user1).setApprovalForAll(cg.address, true);
    await cg.connect(user1).stake(0, 300);
    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")
    await cg.rebase()
    let index = await miceRebaser.index()
    console.log(index)
    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")
    await cg.connect(user1).stake(0, 100);
    await cg.rebase()
    index = await miceRebaser.index()
    console.log(index)
    epoch = await cg.epoch()
    //console.log(epoch)
    let rewards = await cg.getRewards(owner.address, 0)
    console.log(rewards)
    //rewards = await cg.getRewards(owner.address, 0)
    //console.log(rewards)
    expect(parseInt(rewards.toString())).to.be.equal(600000000000);
  });

  it('Should distribute cat rewards', async function () { 
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(1, 10);
    await cg.stake(0, 600);
    index = await catRebaser.index()
    console.log(index)

    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")
    await cg.rebase()
    await cg.claimRewards(0)

    console.log(await cheez.balanceOf(owner.address))
    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")
    await cg.rebase()
    index = await catRebaser.index()
    console.log(index)
    
    let rewards = await cg.getRewards(owner.address, 1)
    console.log(rewards)
    await cg.claimRewards(1)
    console.log(await cheez.balanceOf(owner.address))

    await network.provider.send("evm_increaseTime", [100 + 172801])
    let balanceBefore = await nft.balanceOf(owner.address, 0)
    await cg.unstake(0, 600);

  });

  it('Unstake mice', async function () { 
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(0, 1);
    await cg.stake(2, 1);
    await network.provider.send("evm_increaseTime", [100 + 172801])
    let balanceBefore = await nft.balanceOf(owner.address, 0)
    await cg.unstake(0, 1);
    let balanceAfter = await nft.balanceOf(owner.address, 0)
    expect(parseInt(balanceBefore)).to.be.lessThan(parseInt(balanceAfter));
  });

  it('Should allow more staked', async function () { 
    await nft.setApprovalForAll(cg.address, true);
    await cg.stake(1, 10);
    await cg.stake(0, 100);

    await nft.connect(user1).mintNFTs(1000)
    await nft.connect(user1).setApprovalForAll(cg.address, true);
    await cg.connect(user1).stake(0, 100);

    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")
    await cg.rebase()

    let rewards = await cg.getRewards(owner.address, 0)
    console.log(rewards)

    await cg.connect(user1).stake(0, 100);
    await network.provider.send("evm_increaseTime", [28801])
    await network.provider.send("evm_mine")
    await cg.rebase()
    rewards = await cg.getRewards(owner.address, 0)
    console.log(rewards)

  });



});
