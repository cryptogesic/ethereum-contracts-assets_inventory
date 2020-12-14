const safeMint = async function(contract, to, id, value, data, overrides) {
    return contract.safeMint(to, id, value, data, overrides);
};

const safeBatchMint = async function(contract, to, ids, values, data, overrides) {
    return contract.safeBatchMint(to, ids, values, data, overrides);
};

module.exports = {
    contract: "ERC1155InventoryMock",
    nfMaskLength: 32,
    revertMessages: {
        NonApproved: "Inventory: non-approved sender",
        NonApproved_Batch: "Inventory: non-approved sender",
        SelfApproval: "Inventory: self-approval",
        ZeroAddress: "Inventory: zero address",
        TransferToZero: "Inventory: transfer to zero",
        InconsistentArrays: "Inventory: inconsistent arrays",
        InsufficientBalance: "Inventory: not enough balance",
        TransferRejected: "Inventory: transfer refused",
        NonExistingNFT: "Inventory: non-existing NFT",
        NonOwnedNFT: "Inventory: non-owned NFT",
    },
    safeMint,
    safeBatchMint,
    mint: safeMint,
    batchMint: safeBatchMint,
};
