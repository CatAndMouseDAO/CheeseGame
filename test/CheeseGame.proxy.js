// test/CheeseGame.js
// Load dependencies
const { expect } = require('chai');
const { ethers } = require("hardhat");

let cg;
let nft;
let owner;
// Start test block
describe('CheeseGame', function () {
  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    NFT = await ethers.getContractFactory("NFT");
    nft = await NFT.deploy();

    CG = await ethers.getContractFactory("CheeseGame");
    cg = await upgrades.deployProxy(CG, [nft.address], { kind: 'uups' });

  });
 
  // Test case
  it('retrieve index', async function () { 
    expect((await cg.index()).toString()).to.equal('1100000000');
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

});
