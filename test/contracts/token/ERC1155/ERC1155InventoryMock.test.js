const {artifacts} = require('hardhat');
const {shouldBehaveLikeERC1155} = require('./behaviors/ERC1155.behavior');

const implementation = {
  contractName: 'ERC1155InventoryMock',
  nfMaskLength: 32,
  revertMessages: {
    NonApproved: 'Inventory: non-approved sender',
    SelfApproval: 'Inventory: self-approval',
    ZeroAddress: 'Inventory: zero address',
    TransferToZero: 'Inventory: transfer to zero',
    InconsistentArrays: 'Inventory: inconsistent arrays',
    InsufficientBalance: 'Inventory: not enough balance',
    TransferRejected: 'Inventory: transfer refused',
    NonExistingNFT: 'Inventory: non-existing NFT',
    NonOwnedNFT: 'Inventory: non-owned NFT',
    WrongNFTValue: 'Inventory: wrong NFT value',
    ZeroValue: 'Inventory: zero value',
    NotToken: 'Inventory: not a token id',
    NotNFT: 'Inventory: not an NFT',
    NotCollection: 'Inventory: not a collection',
    ExistingCollection: 'Inventory: existing collection',
    ExistingOrBurntNFT: 'Inventory: existing/burnt NFT',
    NotMinter: 'MinterRole: caller does not have the Minter role',
    SupplyOverflow: 'Inventory: supply overflow',
  },
  interfaces: {ERC1155: true, ERC1155MetadataURI: true, ERC1155Inventory: true, ERC1155InventoryCreator: true},
  methods: {
    'safeMint(address,uint256,uint256,bytes)': async function (contract, to, id, value, data, overrides) {
      return contract.safeMint(to, id, value, data, overrides);
    },
    'safeBatchMint(address,uint256[],uint256[],bytes)': async function (contract, to, ids, values, data, overrides) {
      return contract.safeBatchMint(to, ids, values, data, overrides);
    },
    'createCollection(uint256)': async function (contract, collectionId, overrides) {
      return contract.createCollection(collectionId, overrides);
    },
  },
  deploy: async function (deployer) {
    return artifacts.require('ERC1155InventoryMock').new({from: deployer});
  },
  mint: async function (contract, to, id, value, overrides) {
    return contract.methods['safeMint(address,uint256,uint256,bytes)'](to, id, value, '0x', overrides);
  },
};

describe('ERC1155InventoryMock', function () {
  this.timeout(0);
  shouldBehaveLikeERC1155(implementation);
});
