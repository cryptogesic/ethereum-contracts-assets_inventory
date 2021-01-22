// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ERC1155721Inventory.sol";
import "../ERC1155/IERC1155InventoryBurnable.sol";

/**
 * @title ERC1155721BurnableInventory, a burnable ERC1155721Inventory.
 */
abstract contract ERC1155721BurnableInventory is IERC1155InventoryBurnable, ERC1155721Inventory {
    /**
     * @dev See {IERC1155721InventoryBurnable-burnFrom(address,uint256,uint256)}.
     */
    function burnFrom(
        address from,
        uint256 id,
        uint256 value
    ) external virtual override {
        address sender = _msgSender();
        bool operatable = _isOperatable(from, sender);

        if (isFungible(id)) {
            _burnFungible(from, id, value, operatable);
        } else if (id & _NF_TOKEN_MASK != 0) {
            _burnNFT(from, id, value, operatable, false);
            emit Transfer(from, address(0), id);
        } else {
            revert("Inventory: not a token id");
        }

        emit TransferSingle(sender, from, address(0), id, value);
    }

    /**
     * @dev See {IERC1155721InventoryBurnable-batchBurnFrom(address,uint256[],uint256[])}.
     */
    function batchBurnFrom(
        address from,
        uint256[] calldata ids,
        uint256[] calldata values
    ) external virtual override {
        uint256 length = ids.length;
        require(length == values.length, "Inventory: inconsistent arrays");

        address sender = _msgSender();
        bool operatable = _isOperatable(from, sender);

        uint256 nfCollectionId;
        uint256 nfCollectionCount;
        uint256 nftsCount;
        for (uint256 i; i != length; ++i) {
            uint256 id = ids[i];
            if (isFungible(id)) {
                _burnFungible(from, id, values[i], operatable);
            } else if (id & _NF_TOKEN_MASK != 0) {
                _burnNFT(from, id, values[i], operatable, true);
                emit Transfer(from, address(0), id);
                uint256 nextCollectionId = id & _NF_COLLECTION_MASK;
                if (nfCollectionId == 0) {
                    nfCollectionId = nextCollectionId;
                    nfCollectionCount = 1;
                } else {
                    if (nextCollectionId != nfCollectionId) {
                        _burnNFTUpdateBalanceAndSupply(from, id & _NF_COLLECTION_MASK, nfCollectionCount);

                        nfCollectionId = nextCollectionId;
                        nftsCount += nfCollectionCount;
                        nfCollectionCount = 1;
                    } else {
                        ++nfCollectionCount;
                    }
                }
            } else {
                revert("Inventory: not a token id");
            }
        }

        if (nfCollectionId != 0) {
            // cannot underflow as balance is verified through ownership
            _balances[nfCollectionId][from] -= nfCollectionCount;
            _supplies[nfCollectionId] -= nfCollectionCount;
            nftsCount += nfCollectionCount;
            _nftBalances[from] -= nftsCount;
        }

        emit TransferBatch(sender, from, address(0), ids, values);
    }

    function _burnNFTUpdateBalanceAndSupply(
        address from,
        uint256 collectionId,
        uint256 amount
    ) internal virtual {
        // cannot underflow as balance is verified through NFT ownership
        _balances[collectionId][from] -= amount;
        _supplies[collectionId] -= amount;
    }

    function _burnFungible(
        address from,
        uint256 id,
        uint256 value,
        bool operatable
    ) internal {
        require(value != 0, "Inventory: zero value");
        require(operatable, "Inventory: non-approved sender");
        uint256 balance = _balances[id][from];
        require(balance >= value, "Inventory: not enough balance");
        _balances[id][from] = balance - value;
        // Cannot underflow
        _supplies[id] -= value;
    }

    function _burnNFT(
        address from,
        uint256 id,
        uint256 value,
        bool operatable,
        bool isBatch
    ) internal virtual {
        require(value == 1, "Inventory: wrong NFT value");
        uint256 owner = _owners[id];
        require(from == address(owner), "Inventory: non-owned NFT");
        if (!operatable) {
            require((owner & _APPROVAL_BIT_TOKEN_OWNER_ != 0) && _msgSender() == _nftApprovals[id], "Inventory: non-approved sender");
        }
        _owners[id] = _BURNT_NFT_OWNER;

        if (!isBatch) {
            _burnNFTUpdateBalanceAndSupply(from, id & _NF_COLLECTION_MASK, 1);

            // cannot underflow as balance is verified through NFT ownership
            --_nftBalances[from];
        }
    }
}
