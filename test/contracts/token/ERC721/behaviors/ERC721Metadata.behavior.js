const {accounts, web3} = require('hardhat');
const {createFixtureLoader} = require('@cryptogesic/ethereum-contracts-core_library/test/utils/fixture');
const {expectRevert} = require('@openzeppelin/test-helpers');
const {makeNonFungibleTokenId} = require('@cryptogesic/blockchain-inventory_metadata').inventoryIds;

const {behaviors} = require('@cryptogesic/ethereum-contracts-core_library');
const interfaces = require('../../../../../src/interfaces/ERC165/ERC721');

function shouldBehaveLikeERC721Metadata({nfMaskLength, name, symbol, revertMessages, deploy, mint}) {
  const [deployer, owner] = accounts;

  const nft1 = makeNonFungibleTokenId(1, 1, nfMaskLength);
  const nft2 = makeNonFungibleTokenId(2, 1, nfMaskLength);

  describe('like an ERC721Metadata', function () {
    const fixtureLoader = createFixtureLoader(accounts, web3.eth.currentProvider);
    const fixture = async function () {
      this.token = await deploy(deployer);
    };

    beforeEach(async function () {
      await fixtureLoader(fixture, this);
    });

    it('has a name', async function () {
      (await this.token.name()).should.be.equal(name);
    });

    it('has a symbol', async function () {
      (await this.token.symbol()).should.be.equal(symbol);
    });

    describe('tokenURI', function () {
      beforeEach(async function () {
        await mint(this.token, owner, nft1, 1, {from: deployer});
      });

      it('tokenURI()', async function () {
        await this.token.tokenURI(nft1);
        await expectRevert(this.token.tokenURI(nft2), revertMessages.NonExistingNFT);
      });
    });

    behaviors.shouldSupportInterfaces([interfaces.ERC721Metadata]);
  });
}

module.exports = {
  shouldBehaveLikeERC721Metadata,
};
